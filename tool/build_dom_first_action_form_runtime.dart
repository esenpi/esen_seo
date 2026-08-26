import 'dart:convert';
import 'dart:io';

const _generated = 'lib/src/renderer/seo_dom_first_action_form_runtime.g.dart';

Future<void> main(List<String> arguments) async {
  final write = arguments.contains('--write');
  if (arguments.any((argument) => argument != '--write')) {
    stderr.writeln(
      'Usage: dart run tool/build_dom_first_action_form_runtime.dart [--write]',
    );
    exitCode = 64;
    return;
  }

  const javascript = '(()=>{'
      'let d=document,C=d.querySelectorAll("#esen-seo-content"),c=C[0];'
      'if(C.length!=1||c.dataset.esenSeoDomFirst!="true"||'
      'typeof fetch!="function"||typeof AbortController!="function"||'
      'typeof URLSearchParams!="function"||typeof FormData!="function")return;'
      'let I=new Map;for(let e of d.querySelectorAll("[id]"))'
      'I.set(e.id,(I.get(e.id)||0)+1);'
      'let A=new Set,R=c.querySelectorAll('
      '\'[data-esen-component="action-form"][data-esen-action-form-root]\');'
      'for(let r of R){'
      'let a=(r.dataset.esenActionFormRoot||"").trim(),'
      'F=r.querySelectorAll(\':scope > form[data-esen-action-form]\'),f=F[0],'
      'u=f&&new URL(f.action,location.href);'
      'if(!/^[a-z][a-z0-9_-]{0,63}\$/.test(a)||A.has(a)||F.length!=1||'
      'r.localName!="section"||r.id!="esen-action-form-"+a||I.get(r.id)!=1||'
      'f.dataset.esenActionForm!=a||f.method.toLowerCase()!="post"||'
      'u.pathname!="/_esen_seo/forms/"+a||u.origin!=location.origin||'
      'u.search||u.hash||'
      'f.dataset.esenEnhanced=="true")continue;'
      'let blocked=false;for(let e=r;;e=e.parentElement){'
      'if(e.hasAttribute("inert")||/^\\s*true\\s*\$/i.test('
      'e.getAttribute("aria-hidden"))){blocked=true;break}if(e==c)break}'
      'if(blocked)continue;'
      'let Q=f.querySelectorAll("[data-esen-action-form-control]"),'
      'E=f.querySelectorAll("[data-esen-action-form-error]"),'
      'B=f.querySelectorAll("[data-esen-action-form-submit]"),'
      'S=f.querySelectorAll("[data-esen-action-form-status]"),N=new Set;'
      'if(Q.length<1||Q.length>8||E.length!=Q.length||B.length!=1||S.length!=1)'
      'continue;let b=B[0],s=S[0],pending=(b.dataset.esenPendingLabel||"").trim(),'
      'failure=(f.dataset.esenFailureLabel||"").trim();'
      'if(b.localName!="button"||b.type!="submit"||s.localName!="p"||'
      '!pending||pending.length>120||!failure||failure.length>120)continue;'
      'let ok=true;for(let i=0;i<Q.length;i++){let q=Q[i],e=E[i],'
      'n=q.name,p=String(i),t=(q.type||"").toLowerCase(),w=q.parentElement,'
      'k=w.dataset.esenActionFormKind,valid='
      '(k=="multiline"&&q.localName=="textarea")||'
      '(q.localName=="input"&&((k=="text"&&t=="text")||'
      '(k=="email"&&t=="email")||'
      '(k=="consent"&&t=="checkbox"&&q.value=="accepted")))||'
      '(k=="choice"&&q.localName=="select"&&t=="select-one"&&(()=>{'
      'let O=Array.from(q.children),V=new Set;return O.length>=3&&O.length<=13&&'
      'O.every((o,j)=>o.localName=="option"&&(o.textContent||"").trim()&&'
      '(j==0?o.value=="":/^[a-z][a-z0-9_-]{0,31}\$/.test(o.value)&&'
      '!V.has(o.value)&&(V.add(o.value)||true)))})());'
      'if(q.dataset.esenActionFormControl!=p||'
      'e.dataset.esenActionFormError!=p||!q.id||I.get(q.id)!=1||'
      '!e.id||I.get(e.id)!=1||!new RegExp("^[a-z][a-z0-9_]{0,31}\$").test(n)||'
      'N.has(n)||!valid||'
      'w!=e.parentElement||w.parentElement!=f||'
      'w.dataset.esenActionFormField!=p||e.localName!="span"||'
      '!q.getAttribute("aria-describedby").split(/\\s+/).includes(e.id))'
      '{ok=false;break}N.add(n)}if(!ok)continue;A.add(a);'
      'let g=0,x=null,busy=false;'
      'let clear=(q,i)=>{let e=E[i];q.setCustomValidity("");'
      'q.removeAttribute("aria-invalid");e.textContent="";e.hidden=true};'
      'for(let i=0;i<Q.length;i++){Q[i].addEventListener("input",()=>clear(Q[i],i));'
      'Q[i].addEventListener("change",()=>clear(Q[i],i))}'
      'f.addEventListener("submit",async e=>{if(busy){e.preventDefault();return}'
      'e.preventDefault();'
      'if(!f.reportValidity())return;let k=++g,o=b.textContent||"";busy=true;'
      'b.disabled=true;b.textContent=pending;'
      'r.setAttribute("aria-busy","true");x=new AbortController;'
      'try{let p=await fetch(f.action,{method:"POST",headers:{'
      'Accept:"application/json"},body:new URLSearchParams(new FormData(f)),'
      'credentials:"same-origin",signal:x.signal}),ct=p.headers.get("content-type")||"";'
      'if(k!=g)return;if(!ct.toLowerCase().startsWith("application/json"))throw 0;'
      'let j=await p.json();if(k!=g)return;let keys=Object.keys(j).sort().join(","),'
      'z=j.fieldErrors;if(keys!="fieldErrors,message,ok,schema"||j.schema!==1||'
      'typeof j.ok!="boolean"||typeof j.message!="string"||!j.message.trim()||'
      'j.message.length>512||!z||Array.isArray(z)||typeof z!="object")throw 0;'
      'let Z=Object.keys(z);if(j.ok&&Z.length||Z.some(n=>!N.has(n)||'
      'typeof z[n]!="string"||!z[n].trim()||z[n].length>256))throw 0;'
      'for(let i=0;i<Q.length;i++)clear(Q[i],i);s.textContent=j.message;'
      'for(let n of Z){let i=Array.from(Q).findIndex(q=>q.name==n),q=Q[i],v=z[n];'
      'E[i].textContent=v;E[i].hidden=false;q.setCustomValidity(v);'
      'q.setAttribute("aria-invalid","true")}if(j.ok)f.reset()'
      '}catch(_){if(k==g&&!(x&&x.signal.aborted))s.textContent=failure}'
      'finally{if(k==g){busy=false;b.disabled=false;b.textContent=o;'
      'r.removeAttribute("aria-busy");x=null}}});'
      'addEventListener("pagehide",()=>{g++;if(x)x.abort()},{once:true});'
      'f.dataset.esenEnhanced="true"}'
      '})();';

  if (javascript.toLowerCase().contains('</script') ||
      javascript.contains('<!--')) {
    stderr.writeln('Refusing a runtime containing unsafe inline code.');
    exitCode = 1;
    return;
  }
  final encoded = jsonEncode(javascript).replaceAll(r'$', r'\$');
  final unformattedSource =
      '// Generated by tool/build_dom_first_action_form_runtime.dart.\n'
      '// Do not edit by hand.\n'
      'const String seoDomFirstActionFormRuntime = $encoded;\n';

  final temp =
      await Directory.systemTemp.createTemp('esen-action-form-runtime-');
  try {
    final sourceFile = File('${temp.path}/runtime.dart');
    await sourceFile.writeAsString(unformattedSource);
    final formatResult = await Process.run(
      Platform.resolvedExecutable,
      ['format', sourceFile.path],
      runInShell: false,
    );
    if (formatResult.exitCode != 0) {
      stderr.write(formatResult.stdout);
      stderr.write(formatResult.stderr);
      exitCode = formatResult.exitCode;
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
    stdout.writeln('DOM-first action form runtime is current.');
  } finally {
    await temp.delete(recursive: true);
  }
}
