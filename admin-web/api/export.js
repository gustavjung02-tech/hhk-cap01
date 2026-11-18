import QRCode from 'qrcode';
import JSZip from 'jszip';
import {apiHeaders, allowedOrigin, error, readBody, checkedTokens,
  checkedBatchCode, csvForBatch} from '../lib/shared.js';

export default async function handler(req,res) {
  apiHeaders(res);
  if (req.method!=='POST') return error(res,405,'METHOD_NOT_ALLOWED');
  if (!allowedOrigin(req)) return error(res,403,'BAD_ORIGIN');
  let tokens, batchCode;
  try {
    const body=readBody(req);
    tokens=checkedTokens(body.tokens);
    batchCode=checkedBatchCode(body.batchCode);
  } catch {
    return error(res,400,'INVALID_EXPORT_REQUEST');
  }
  try {
    const archive=new JSZip();
    archive.file('QR_CLAIM_TOKENS.csv',csvForBatch(batchCode,tokens));
    for (let i=0;i<tokens.length;i++) {
      const svg=await QRCode.toString(tokens[i], {
        type:'svg',errorCorrectionLevel:'M',margin:2,width:512
      });
      archive.file('qr/'+String(i+1).padStart(3,'0')+'.svg',svg);
    }
    const zip=await archive.generateAsync({type:'nodebuffer',
      compression:'DEFLATE',compressionOptions:{level:6}});
    res.setHeader('Content-Type','application/zip');
    res.setHeader('Content-Disposition',
      'attachment; filename="HHK_QR_'+batchCode+'.zip"');
    res.setHeader('Content-Length',String(zip.byteLength));
    return res.status(200).send(zip);
  } catch {
    return error(res,500,'QR_EXPORT_FAILED');
  }
}
