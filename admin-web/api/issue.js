import {apiHeaders, allowedOrigin, error, readBody} from './_shared.js';

// Fixed destination: only the existing HHK staging license backend is authorized.
// A user's admin API key is supplied interactively and forwarded transiently.
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
  const auth=req.headers?.authorization;
  if (typeof auth!=='string' || !/^Bearer [^\s]{16,512}$/.test(auth)) {
    return error(res,401,'ADMIN_KEY_REQUIRED');
  }
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
