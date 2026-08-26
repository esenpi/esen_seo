import 'dart:convert';
import 'dart:io';

const _generated = 'lib/src/renderer/seo_dom_first_action_flow_runtime.g.dart';

Future<void> main(List<String> arguments) async {
  final write = arguments.contains('--write');
  if (arguments.any((argument) => argument != '--write')) {
    stderr.writeln(
      'Usage: dart run tool/build_dom_first_action_flow_runtime.dart [--write]',
    );
    exitCode = 64;
    return;
  }

  const javascript = r'''(()=>{
let d=document,C=d.querySelectorAll("#esen-seo-content"),c=C[0];
if(C.length!=1||c.dataset.esenSeoDomFirst!="true"||typeof fetch!="function"||typeof AbortController!="function"||typeof URLSearchParams!="function"||typeof FormData!="function")return;
let I=new Map;for(let e of d.querySelectorAll("[id]"))I.set(e.id,(I.get(e.id)||0)+1);
let safe=(v,n)=>typeof v==="string"&&v.trim()&&v.length<=n&&!/[\u0000-\u001f\u007f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]/.test(v),A=new Set;
for(let r of c.querySelectorAll('[data-esen-component="action-flow"][data-esen-action-flow-root]')){
 let a=(r.dataset.esenActionFlowRoot||"").trim(),rid="esen-action-flow-"+a,K=r.children,h=K[0],desc=K[1],p=K[2],f=K[3];
 if(!/^[a-z][a-z0-9_-]{0,63}$/.test(a)||A.has(a)||r.localName!="section"||r.id!=rid||r.className!=="esen-seo-action-flow"||I.get(rid)!=1||r.dataset.esenLayoutStable!="true"||r.dataset.esenEnhanced==="true"||K.length!=4||!/^h[1-6]$/.test(h&&h.localName)||!safe(h.textContent,120)||desc.localName!="p"||desc.className!=="esen-seo-action-form-description"||!safe(desc.textContent,512)||p.localName!="ol"||p.className!=="esen-seo-action-flow-progress"||!safe(p.getAttribute("aria-label"),120)||f.localName!="form"||f.dataset.esenActionFlow!=a||f.method.toLowerCase()!="post"||f.getAttribute("action")!="/_esen_seo/forms/"+a||f.dataset.esenEnhanced==="true")continue;
 let blocked=false;for(let e=r;;e=e.parentElement){if(e.hasAttribute("inert")||/^\s*true\s*$/i.test(e.getAttribute("aria-hidden"))){blocked=true;break}if(e==c)break}if(blocked)continue;
 let P=Array.from(p.children),n=P.length;if(n<2||n>6||P.some((e,i)=>e.localName!="li"||e.dataset.esenActionFlowProgress!=String(i)||e.hasAttribute("aria-current")||!safe(e.textContent,120))||f.children.length!=n+3)continue;
 let T=[],H=[],Q=[],E=[],O=[],N=new Set,ok=true;
 for(let si=0;si<n&&ok;si++){
  let s=f.children[si],S=s.children,head=S[0],sd=S[1],hid=rid+"-step-"+si+"-heading";
  if(s.localName!="section"||s.className!=="esen-seo-action-flow-step"||s.dataset.esenActionFlowStep!=String(si)||s.hasAttribute("hidden")||s.getAttribute("aria-labelledby")!=hid||S.length<3||!/^h[1-6]$/.test(head&&head.localName)||head.id!=hid||I.get(hid)!=1||head.getAttribute("tabindex")!="-1"||head.textContent!=P[si].textContent||sd.localName!="p"||!safe(sd.textContent,512)){ok=false;break}
  T.push(s);H.push(head);
  for(let ci=2;ci<S.length;ci++){
   let w=S[ci],F=w.children,fi=Q.length,has=F.length==4,label=F[0],hint=has?F[1]:null,q=F[has?2:1],e=F[has?3:2],id=rid+"-field-"+fi,eid=id+"-error",did=id+"-description",kind=w.dataset.esenActionFormKind,name=q&&q.name,type=(q&&q.type||"").toLowerCase(),described=(q&&q.getAttribute("aria-describedby")||"").split(/\s+/);
   if(fi>=8||w.localName!="div"||w.className!=="esen-seo-action-form-field"||w.dataset.esenActionFormField!=String(fi)||(F.length!=3&&F.length!=4)||label.localName!="label"||label.getAttribute("for")!=id||!safe(label.textContent,120)||(has&&(hint.localName!="p"||hint.className!=="esen-seo-action-form-hint"||hint.id!=did||I.get(did)!=1||!safe(hint.textContent,512)))||!q||q.id!=id||I.get(id)!=1||q.dataset.esenActionFormControl!=String(fi)||!/^[a-z][a-z0-9_]{0,31}$/.test(name)||N.has(name)||!described.includes(eid)||(has&&!described.includes(did))||e.localName!="span"||e.className!=="esen-seo-action-form-error"||e.id!=eid||I.get(eid)!=1||e.dataset.esenActionFormError!=String(fi)||!e.hasAttribute("hidden")||e.textContent){ok=false;break}
   let valid=(kind==="multiline"&&q.localName==="textarea")||(q.localName==="input"&&((kind==="text"&&type==="text")||(kind==="email"&&type==="email")||(kind==="consent"&&type==="checkbox"&&q.value==="accepted")));
   if(kind==="choice"&&q.localName==="select"&&type==="select-one"){
    let opts=Array.from(q.children),vals=new Set;valid=opts.length>=3&&opts.length<=13&&opts.every((o,i)=>o.localName==="option"&&safe(o.textContent,120)&&(i==0?o.value==="":/^[a-z][a-z0-9_-]{0,31}$/.test(o.value)&&!vals.has(o.value)&&(vals.add(o.value)||true)));
   }
   if(!valid){ok=false;break}N.add(name);Q.push(q);E.push(e);O.push(si);
  }
 }
 let nav=f.children[n],prev=nav&&nav.children[0],next=nav&&nav.children[1],b=f.children[n+1],status=f.children[n+2],pending=b&&(b.dataset.esenPendingLabel||"").trim(),failure=(f.dataset.esenFailureLabel||"").trim();
 if(!ok||!Q.length||f.querySelectorAll("input,textarea,select").length!=Q.length||nav.localName!="div"||nav.className!=="esen-seo-action-flow-navigation"||!nav.hasAttribute("data-esen-action-flow-navigation")||!nav.hasAttribute("hidden")||nav.children.length!=2||prev.localName!="button"||prev.type!="button"||!prev.hasAttribute("data-esen-action-flow-previous")||!safe(prev.textContent,120)||next.localName!="button"||next.type!="button"||!next.hasAttribute("data-esen-action-flow-next")||!safe(next.textContent,120)||b.localName!="button"||b.type!="submit"||!b.hasAttribute("data-esen-action-form-submit")||b.hasAttribute("hidden")||f.querySelectorAll("button").length!=3||status.localName!="p"||status.className!=="esen-seo-action-form-status"||!status.hasAttribute("data-esen-action-form-status")||status.getAttribute("role")!="status"||status.getAttribute("aria-live")!="polite"||!safe(pending,120)||!safe(failure,120))continue;
 A.add(a);let step=0,g=0,x=null,busy=false;
 let hide=(e,v)=>v?e.setAttribute("hidden",""):e.removeAttribute("hidden"),render=(focus=false)=>{T.forEach((e,i)=>{hide(e,i!=step);i==step?P[i].setAttribute("aria-current","step"):P[i].removeAttribute("aria-current")});nav.removeAttribute("hidden");hide(prev,step==0);hide(next,step==n-1);hide(b,step!=n-1);if(focus)H[step].focus()},clear=i=>{Q[i].setCustomValidity("");Q[i].removeAttribute("aria-invalid");E[i].textContent="";E[i].hidden=true},validStep=i=>{for(let j=0;j<Q.length;j++)if(O[j]==i&&!Q[j].checkValidity()){Q[j].reportValidity();return false}return true};
 Q.forEach((q,i)=>{q.addEventListener("input",()=>clear(i));q.addEventListener("change",()=>clear(i))});
 prev.addEventListener("click",()=>{if(!busy&&step>0){step--;render(true)}});next.addEventListener("click",()=>{if(!busy&&validStep(step)&&step<n-1){step++;render(true)}});
 f.addEventListener("submit",async e=>{e.preventDefault();if(busy)return;let invalid=Q.findIndex(q=>!q.checkValidity());if(invalid>=0){step=O[invalid];render();Q[invalid].reportValidity();return}
  let k=++g,old=b.textContent;busy=true;prev.disabled=next.disabled=b.disabled=true;b.textContent=pending;r.setAttribute("aria-busy","true");x=new AbortController;
  try{let response=await fetch(f.action,{method:"POST",headers:{Accept:"application/json"},body:new URLSearchParams(new FormData(f)),credentials:"same-origin",signal:x.signal}),ct=response.headers.get("content-type")||"";if(k!=g)return;if(!ct.toLowerCase().startsWith("application/json"))throw 0;let body=await response.text();if(k!=g)return;if(body.length>8192)throw 0;let j=JSON.parse(body),keys=Object.keys(j).sort().join(","),z=j.fieldErrors;if(keys!="fieldErrors,message,ok,schema"||j.schema!==1||typeof j.ok!=="boolean"||!safe(j.message,512)||!z||Array.isArray(z)||typeof z!=="object")throw 0;let Z=Object.keys(z);if(Z.length>Q.length||(j.ok&&Z.length)||Z.some(name=>!N.has(name)||!safe(z[name],256)))throw 0;Q.forEach((_,i)=>clear(i));status.textContent=j.message;let first=-1;for(let name of Z){let i=Q.findIndex(q=>q.name==name);if(first<0)first=i;E[i].textContent=z[name];E[i].hidden=false;Q[i].setCustomValidity(z[name]);Q[i].setAttribute("aria-invalid","true")}if(first>=0){step=O[first];render()}else if(j.ok){f.reset();step=0;render()}
  }catch(_){if(k==g&&!(x&&x.signal.aborted))status.textContent=failure}finally{if(k==g){busy=false;prev.disabled=next.disabled=b.disabled=false;b.textContent=old;r.removeAttribute("aria-busy");x=null}}
 });
 addEventListener("pagehide",()=>{g++;if(x)x.abort()},{once:true});f.dataset.esenEnhanced="true";r.dataset.esenEnhanced="true";render();
}
})();''';

  if (javascript.toLowerCase().contains('</script') ||
      javascript.contains('<!--')) {
    stderr.writeln('Refusing a runtime containing unsafe inline code.');
    exitCode = 1;
    return;
  }
  final encoded = jsonEncode(javascript).replaceAll(r'$', r'\$');
  final unformattedSource =
      '// Generated by tool/build_dom_first_action_flow_runtime.dart.\n'
      '// Do not edit by hand.\n'
      'const String seoDomFirstActionFlowRuntime = $encoded;\n';
  final temp = await Directory.systemTemp.createTemp('esen-action-flow-');
  try {
    final sourceFile = File('${temp.path}/runtime.dart');
    await sourceFile.writeAsString(unformattedSource);
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['format', sourceFile.path],
      runInShell: false,
    );
    if (result.exitCode != 0) {
      stderr.write(result.stdout);
      stderr.write(result.stderr);
      exitCode = result.exitCode;
      return;
    }
    final source = await sourceFile.readAsString();
    final target = File(_generated);
    if (write) {
      await target.writeAsString(source);
      stdout.writeln('Wrote $_generated (${javascript.length} JS bytes).');
      return;
    }
    if (!target.existsSync() || await target.readAsString() != source) {
      stderr.writeln('$_generated is stale. Run this command with --write.');
      exitCode = 1;
      return;
    }
    stdout.writeln('DOM-first action flow runtime is current.');
  } finally {
    await temp.delete(recursive: true);
  }
}
