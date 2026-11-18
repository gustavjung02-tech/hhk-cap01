import {apiHeaders, allowedOrigin, error, readBody} from '../lib/shared.js';

// Fixed destination: only the existing HHK staging license backend is authorized.
// A scoped secret is injected by Vercel server-side only, guarded by Vercel Authentication.
const STAGING_BACKEND='https://hhk-cap01-license-staging-gustavjung02-techs-projects.vercel.app';
const paths={
  campaign:'/api/v1/admin/campaigns',
  batch:'/api/v1/admin/batches',
  list:'/api/v1/admin/batches'
};

export default async function handler(req,res) {
  apiHeaders(res);
  if (!allowedOrigin(req)) return error(res,403,'BAD_ORIGIN');
  const selected=new URL(req.url||'/api/issue','https://hhk-cap01-admin.vercel.app')
    .searchParams.get('action');
  if (!(selected in paths)) return error(res,404,'UNKNOWN_ACTION');
  const method=selected==='list'?'GET':'POST';
  if (req.method!==method) {
    res.setHeader('Allow',method);
    return error(res,405,'METHOD_NOT_ALLOWED');
  }
  const panelKey=process.env.HHK_ADMIN_PANEL_KEY;
  if (typeof panelKey!=='string' || panelKey.length<32) {
    return error(res,503,'PANEL_NOT_CONFIGURED');
  }
  const auth='Bearer '+panelKey;
  let body;
  if (method==='POST') {
    try { body=readBody(req); }
    catch { return error(res,400,'INVALID_BODY'); }
  }
  try {
    const upstream=await fetch(STAGING_BACKEND+paths[selected], {
      method,
      headers:{
        'authorization':auth,
        ...(method==='POST'?{'content-type':'application/json'}:{})
      },
      ...(method==='POST'?{body:JSON.stringify(body)}:{}),
      redirect:'error',
      signal:AbortSignal.timeout(12000),
      cache:'no-store'
    });
    let result;
    try { result=await upstream.json(); }
    catch { return error(res,502,'BACKEND_BAD_RESPONSE'); }
    if (!result || typeof result!=='object' || Array.isArray(result)) {
      return error(res,502,'BACKEND_BAD_RESPONSE');
    }
    return res.status(upstream.status).json(result);
  } catch {
    return error(res,503,'BACKEND_UNAVAILABLE');
  }
}
