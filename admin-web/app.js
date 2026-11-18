// Tokens exist only in memory until the operator downloads them.
const $=id=>document.getElementById(id);
const campaignCode=$('campaign-code');
const batchCampaign=$('batch-campaign'), batchCode=$('batch-code');
let issued=null, downloaded=false, busy=false;
let urls=[];

function newCode(prefix) {
  const date=new Date().toISOString().slice(0,10).replace(/-/g,'');
  const entropy=Array.from(crypto.getRandomValues(new Uint8Array(4)),
    n=>n.toString(16).padStart(2,'0')).join('').toUpperCase();
  return prefix+'_'+date+'_'+entropy;
}
campaignCode.value=newCode('CAMP');
batchCampaign.value=campaignCode.value;
batchCode.value=newCode('BATCH');
const errors={
  UNAUTHORIZED:'Khóa quản trị không hợp lệ.',
  PANEL_NOT_CONFIGURED:'Máy chủ quản trị chưa cấu hình credential cấp QR.',
  INVALID_CAMPAIGN:'Mã chương trình, quyền lớp hoặc thời hạn không hợp lệ.',
  INVALID_BATCH:'Mã đợt hoặc số lượng mã không hợp lệ.',
  CONFLICT:'Mã chương trình hoặc mã đợt đã tồn tại. Hãy dùng mã mới.',
  CAMPAIGN_NOT_ACTIVE:'Chương trình chưa tạo hoặc không hoạt động.',
  BACKEND_UNAVAILABLE:'Backend staging hiện không sẵn sàng.',
  BACKEND_BAD_RESPONSE:'Máy chủ trả về dữ liệu không hợp lệ.',
  QR_RENDER_FAILED:'Không thể dựng hình QR.',
  INVALID_TOKEN_LIST:'Mã QR không hợp lệ.',
  BAD_ORIGIN:'Yêu cầu không được phép.'
};
function inform(text,kind='info'){
  $('status').textContent=text;
  $('status').className='status '+kind;
}
function setBusy(v){
  busy=v;
  for(const id of ['verify-btn','campaign-btn','batch-btn','refresh-btn','download-zip'])
    $(id).disabled=v;
}
function validCode(value){return /^[A-Z0-9][A-Z0-9_-]{2,39}$/.test(value)}
async function api(url,{method='POST',body}={}){
  const headers={'content-type':'application/json'};
  let response;
  try{
    response=await fetch(url,{
      method,headers,cache:'no-store',
      ...(body===undefined?{}:{body:JSON.stringify(body)})
    });
  }catch{throw new Error('BACKEND_UNAVAILABLE')}
  if((response.headers.get('content-type')||'').includes('application/zip')){
    if(!response.ok)throw new Error('QR_EXPORT_FAILED');
    return response.blob();
  }
  let data;
  try{data=await response.json()}
  catch{throw new Error('BACKEND_BAD_RESPONSE')}
  if(!response.ok||data.ok!==true)throw new Error(data.code||'BACKEND_UNAVAILABLE');
  return data;
}
async function run(callback){
  if(busy)return;
  setBusy(true);
  try{await callback()}
  catch(e){inform(errors[e.message]||e.message||'Có lỗi xảy ra.','error')}
  finally{setBusy(false)}
}
$('verify-btn').addEventListener('click',()=>run(async()=>{
  const info=await api('/api/issue?action=list',{method:'GET',admin:true});
  drawHistory(info.batches);
  inform('Đã kết nối thành công. Đã tải '+info.batches.length+' đợt gần nhất.','success');
}));
$('campaign-form').addEventListener('submit',event=>{
  event.preventDefault();
  run(async()=>{
    const code=campaignCode.value.trim().toUpperCase();
    const grades=Array.from(document.querySelectorAll('input[name="grade"]:checked'),
      checkbox=>Number(checkbox.value));
    const validDays=Number($('valid-days').value);
    const maxDevices=Number($('max-devices').value);
    if(!validCode(code)||grades.length===0||!Number.isInteger(validDays)||
      validDays<1||validDays>3650||!Number.isInteger(maxDevices)||
      maxDevices<1||maxDevices>10)throw new Error('INVALID_CAMPAIGN');
    await api('/api/issue?action=campaign',{admin:true,body:{
      campaignCode:code,active:true,policy:{grades,validDays,maxDevices}
    }});
    batchCampaign.value=code;
    inform('Đã tạo chương trình '+code+'. Anh có thể phát hành đợt QR ở khung bên phải.','success');
  });
});
$('batch-form').addEventListener('submit',event=>{
  event.preventDefault();
  run(async()=>{
    if(issued&&!downloaded&&!confirm(
      'Mã cũ chưa được tải. Phát hành tiếp sẽ bỏ mã cũ khỏi màn hình. Tiếp tục?'))return;
    const code=batchCode.value.trim().toUpperCase();
    const program=batchCampaign.value.trim().toUpperCase();
    const quantityTokens=Number($('token-count').value);
    if(!validCode(code)||!validCode(program)||!Number.isInteger(quantityTokens)||
      quantityTokens<1||quantityTokens>100)throw new Error('INVALID_BATCH');
    const result=await api('/api/issue?action=batch',{admin:true,body:{
      batchCode:code,campaignCode:program,quantityTokens
    }});
    if(!Array.isArray(result.qrTokens)||result.qrTokens.length!==quantityTokens||
      result.qrTokens.some(t=>typeof t!=='string'||
        !/^qr_[A-Za-z0-9_-]{32}$/.test(t)))throw new Error('BACKEND_BAD_RESPONSE');
    issued={batchCode:code,campaignCode:program,tokens:result.qrTokens.slice()};
    downloaded=false;
    batchCode.value=newCode('BATCH');
    inform('Đã phát hành '+quantityTokens+' mã. Tải ZIP hoặc CSV ngay để lưu mã gốc.','success');
    await renderQrs();
    await refreshHistory();
    $('results').scrollIntoView({behavior:'smooth',block:'start'});
  });
});
function drawHistory(rows){
  const tbody=$('history-body');
  tbody.replaceChildren();
  if(!Array.isArray(rows)||rows.length===0){
    const tr=document.createElement('tr'),cell=document.createElement('td');
    cell.colSpan=6;cell.className='empty';cell.textContent='Chưa có đợt mã nào.';
    tr.append(cell);tbody.append(tr);return;
  }
  for(const item of rows){
    const tr=document.createElement('tr'),date=new Date(item.createdAt);
    const columns=[item.batchCode,item.campaignCode||'—',
      Number.isFinite(date.getTime())?date.toLocaleString('vi-VN'):'—',
      item.quantityTokens,item.redeemed,item.unclaimed];
    for(const value of columns){
      const cell=document.createElement('td');
      cell.textContent=String(value);tr.append(cell);
    }
    tbody.append(tr);
  }
}
async function refreshHistory(){
  try{
    const data=await api('/api/issue?action=list',{method:'GET',admin:true});
    drawHistory(data.batches);
  }catch(e){inform(errors[e.message]||'Không tải được thống kê.','error')}
}
$('refresh-btn').addEventListener('click',()=>run(refreshHistory));
function clearUrls(){
  for(const url of urls)URL.revokeObjectURL(url);
  urls=[];
}
async function renderQrs(){
  if(!issued)return;
  const item=issued;
  $('results').hidden=false;
  $('result-description').textContent=item.batchCode+' · '+item.tokens.length+
    ' mã · Chương trình '+item.campaignCode;
  $('qr-grid').replaceChildren();
  clearUrls();
  $('qr-status').textContent='Đang tạo ảnh QR...';
  const data=await api('/api/qr',{body:{tokens:item.tokens}});
  if(issued!==item)return;
  if(!Array.isArray(data.svgs)||data.svgs.length!==item.tokens.length)
    throw new Error('QR_RENDER_FAILED');
  data.svgs.forEach((svg,index)=>{
    if(typeof svg!=='string'||!svg.startsWith('<svg'))throw new Error('QR_RENDER_FAILED');
    const card=document.createElement('div');card.className='qr-card';
    const title=document.createElement('strong');title.textContent='HHK · QR '+(index+1);
    const img=document.createElement('img');img.alt='QR số '+(index+1);
    const url=URL.createObjectURL(new Blob([svg],{type:'image/svg+xml'}));
    urls.push(url);img.src=url;
    const token=document.createElement('code');token.textContent=item.tokens[index];
    const copy=document.createElement('button');copy.type='button';copy.textContent='Sao chép mã';
    copy.addEventListener('click',async()=>{
      try{await navigator.clipboard.writeText(item.tokens[index]);
        $('qr-status').textContent='Đã sao chép mã số '+(index+1);
      }catch{$('qr-status').textContent='Không sao chép được, hãy dùng ZIP hoặc CSV.'}
    });
    card.append(title,img,token,copy);$('qr-grid').append(card);
  });
  $('qr-status').textContent='Đã hiển thị đủ '+item.tokens.length+' mã QR.';
}
function download(blob,extension){
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a');a.href=url;
  a.download='HHK_QR_'+issued.batchCode+'.'+extension;
  document.body.append(a);a.click();a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),60000);
}
$('download-csv').addEventListener('click',()=>{
  if(!issued)return;
  const lines=['index,batch_code,qr_token'];
  issued.tokens.forEach((t,i)=>lines.push((i+1)+','+issued.batchCode+','+t));
  const content='\uFEFF'+lines.join('\r\n')+'\r\n';
  download(new Blob([content],{type:'text/csv;charset=utf-8'}),'csv');
  downloaded=true;
  $('qr-status').textContent='Đã tải CSV chứa toàn bộ mã của đợt.';
});
$('download-zip').addEventListener('click',()=>run(async()=>{
  if(!issued)return;
  const zip=await api('/api/export',{body:{
    batchCode:issued.batchCode,tokens:issued.tokens}});
  download(zip,'zip');
  downloaded=true;
  $('qr-status').textContent='Đã tải ZIP gồm ảnh SVG và CSV.';
}));
$('print-btn').addEventListener('click',()=>{
  if(issued&&urls.length===issued.tokens.length)window.print();
});
$('discard-btn').addEventListener('click',()=>{
  if(!issued)return;
  if(!downloaded&&!confirm(
    'Mã chưa được tải về. Sau khi xóa không thể lấy lại. Anh chắc chắn?'))return;
  issued=null;downloaded=false;clearUrls();
  $('qr-grid').replaceChildren();$('results').hidden=true;
  inform('Đã xóa mã khỏi màn hình; thống kê đợt vẫn lưu trong máy chủ.','info');
});
window.addEventListener('beforeunload',event=>{
  if(issued&&!downloaded){event.preventDefault();event.returnValue=''}
});
window.addEventListener('pagehide',clearUrls);
