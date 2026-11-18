#!/usr/bin/env python3
"""Audit metadata and actual TTS ZIPs without trusting the manifest alone."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from zipfile import ZipFile, BadZipFile

AUDIO={".mp3",".wav",".m4a",".aac",".ogg",".opus"}
HEX64=re.compile(r"^[a-f0-9]{64}$")
NAME=re.compile(r"^vi-v1-(pre-k|grade-[1-5])-[0-9-]+-v[0-9]+\.zip$")

def check_manifest(data):
    if data.get("profile")!="vi-v1" or data.get("contentType")!="lesson-card":
        raise ValueError("Unsupported audio manifest")
    rows=data.get("packs")
    if not isinstance(rows,list) or len(rows)!=6:
        raise ValueError("Expected pre-K and five grade audio archives")
    grades=set()
    for p in rows:
        grade=p.get("grade")
        filename=p.get("fileName")
        key=p.get("r2Key")
        url=p.get("r2PublicUrl")
        if type(grade) is not int or grade not in range(6) or grade in grades:
            raise ValueError("Duplicate or invalid grade")
        grades.add(grade)
        if not isinstance(filename,str) or not NAME.fullmatch(filename) or \
           (grade==0) != ("-pre-k-" in filename) or \
           (grade>0 and f"-grade-{grade}-" not in filename):
            raise ValueError("Invalid audio pack filename")
        if key!="audio/tts/packs/"+filename or \
           not isinstance(url,str) or not url.startswith("https://") or \
           not url.endswith("/"+key) or "?" in url or "#" in url:
            raise ValueError("R2 key and public URL mismatch")
        if p.get("sourceProvider")!="cloudflare-r2" or \
           not isinstance(p.get("driveFileId"),str) or \
           len(p["driveFileId"])<20 or \
           type(p.get("sizeBytes")) is not int or p["sizeBytes"]<=0 or \
           type(p.get("assetCount")) is not int or p["assetCount"]<=0 or \
           not isinstance(p.get("sha256"),str) or \
           not HEX64.fullmatch(p["sha256"]):
            raise ValueError("Invalid archive metadata")
    return rows

def verify_zip(path,p):
    if path.stat().st_size!=p["sizeBytes"]:
        raise ValueError("Archive byte size mismatch")
    digest=hashlib.sha256()
    with path.open("rb") as f:
        while chunk:=f.read(1024*1024):
            digest.update(chunk)
    if digest.hexdigest()!=p["sha256"]:
        raise ValueError("Archive SHA256 mismatch")
    count=0
    seen=set()
    with ZipFile(path) as archive:
        for info in archive.infolist():
            name=info.filename
            if name.startswith("/") or "\\" in name or \
               ".." in Path(name).parts or name in seen or \
               ((info.external_attr>>16)&0o170000)==0o120000:
                raise ValueError("Unsafe ZIP entry")
            seen.add(name)
            if not info.is_dir() and Path(name).suffix.lower() in AUDIO:
                count+=1
                with archive.open(info) as stream:
                    while stream.read(1024*1024):
                        pass
    if count!=p["assetCount"]:
        raise ValueError("Audio file count mismatch")
    return count

def audit(data, zip_dir=None, strict=False):
    rows=[]
    for p in check_manifest(data):
        item={"grade":p["grade"],"fileName":p["fileName"],"expectedFiles":p["assetCount"]}
        path=zip_dir/p["fileName"] if zip_dir else None
        if path is None or not path.is_file():
            item["status"]="MISSING_BINARY"
        else:
            try:
                item["actualFiles"]=verify_zip(path,p)
                item["status"]="VERIFIED_BINARY"
            except (ValueError,OSError,BadZipFile,RuntimeError) as exc:
                item["status"]="INVALID_BINARY"
                item["error"]=str(exc)
        rows.append(item)
    if all(x["status"]=="VERIFIED_BINARY" for x in rows):
        status="VERIFIED_ALL"
    elif any(x["status"]=="INVALID_BINARY" for x in rows) or strict:
        status="BLOCKED"
    else:
        status="MISSING_ASSETS"
    return {"status":status,"verified":sum(x["status"]=="VERIFIED_BINARY" for x in rows),
            "total":len(rows),"packs":rows}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest",default="content/media/tts_drive_packs.json")
    parser.add_argument("--zip-dir",type=Path)
    parser.add_argument("--require-files",action="store_true")
    args=parser.parse_args()
    try:
        data=json.loads(Path(args.manifest).read_text(encoding="utf8"))
        result=audit(data,args.zip_dir,args.require_files)
    except (ValueError,OSError) as exc:
        print(json.dumps({"status":"INVALID_MANIFEST","error":str(exc)}))
        return 2
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return 2 if result["status"]=="BLOCKED" else 0

if __name__=="__main__":
    sys.exit(main())
