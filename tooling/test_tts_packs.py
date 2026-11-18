import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from zipfile import ZipFile

from check_tts_packs import audit, check_manifest, verify_zip


def sample(grade):
    suffix="pre-k" if grade==0 else f"grade-{grade}"
    filename=f"vi-v1-{suffix}-2026-04-27-v1.zip"
    key=f"audio/tts/packs/{filename}"
    return {"grade":grade,"fileName":filename,"r2Key":key,
            "r2PublicUrl":"https://example.r2.dev/"+key,
            "driveFileId":"ABCDabcdefghABCDEFGHIJKL",
            "sourceProvider":"cloudflare-r2","sizeBytes":42,
            "sha256":"f"*64,"assetCount":2}

def manifest():
    return {"profile":"vi-v1","contentType":"lesson-card",
            "packs":[sample(i) for i in range(6)]}

class PackAuditTests(unittest.TestCase):
    def test_only_metadata_is_not_verification(self):
        self.assertEqual(len(check_manifest(manifest())),6)
        self.assertEqual(audit(manifest())["status"],"MISSING_ASSETS")
        self.assertEqual(audit(manifest(),strict=True)["status"],"BLOCKED")

    def test_grade_and_source_path_validation(self):
        data=manifest()
        data["packs"][2]["grade"]=1
        with self.assertRaises(ValueError):
            check_manifest(data)
        data=manifest()
        data["packs"][1]["r2PublicUrl"]="https://evil.invalid/fake.zip"
        with self.assertRaises(ValueError):
            check_manifest(data)

    def test_archive_hash_count_and_unsafe_paths(self):
        with TemporaryDirectory() as directory:
            path=Path(directory)/sample(1)["fileName"]
            with ZipFile(path,"w") as archive:
                archive.writestr("1.mp3",b"audio one")
                archive.writestr("2.mp3",b"audio two")
            row=sample(1)
            content=path.read_bytes()
            row["sizeBytes"]=len(content)
            row["sha256"]=hashlib.sha256(content).hexdigest()
            self.assertEqual(verify_zip(path,row),2)
            row["sha256"]="0"*64
            with self.assertRaisesRegex(ValueError,"SHA256"):
                verify_zip(path,row)
            with ZipFile(path,"w") as archive:
                archive.writestr("../bad.mp3",b"bad")
                archive.writestr("okay.mp3",b"okay")
            content=path.read_bytes()
            row["sizeBytes"]=len(content)
            row["sha256"]=hashlib.sha256(content).hexdigest()
            with self.assertRaisesRegex(ValueError,"Unsafe"):
                verify_zip(path,row)

if __name__=="__main__":
    unittest.main()
