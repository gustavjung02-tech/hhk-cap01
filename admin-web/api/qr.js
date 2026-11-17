import QRCode from 'qrcode';
import {apiHeaders, allowedOrigin, error, readBody, checkedTokens} from './_shared.js';

export default async function handler(req,res) {
  apiHeaders(res);
  if (req.method!=='POST') return error(res,405,'METHOD_NOT_ALLOWED');
  if (!allowedOrigin(req)) return error(res,403,'BAD_ORIGIN');
  let tokens;
  try { tokens=checkedTokens(readBody(req).tokens); }
  catch { return error(res,400,'INVALID_TOKEN_LIST'); }
  try {
    const svgs=await Promise.all(tokens.map(token =>
      QRCode.toString(token, {
        type:'svg', errorCorrectionLevel:'M', margin:2, width:256
      })));
    return res.status(200).json({ok:true,svgs});
  } catch {
    return error(res,500,'QR_RENDER_FAILED');
  }
}
