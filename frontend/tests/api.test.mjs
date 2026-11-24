import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi, ApiError } from '../src/lib/api.mjs';
const reply = (data, status=200) => new Response(data===null?null:JSON.stringify(data), {status});
test('GET uses cookies without CSRF request', async()=>{
 const calls=[]; const api=createApi(async(p,o)=>{calls.push([p,o]);return reply([])});
 assert.deepEqual(await api.request('/samples'),[]);
 assert.equal(calls.length,1);assert.equal(calls[0][1].credentials,'include');
});
test('login uses token A and refreshes it to B',async()=>{
 const calls=[];let tokens=0;
 const api=createApi(async(p,o)=>{calls.push([p,o]);return reply(p.endsWith('/csrf')?{headerName:'X-CSRF',token:++tokens===1?'A':'B'}:{id:1,type:'EMPLOYEE',email:'a@b.org',roles:['ADMIN']})});
 await api.login('a@b.org','password');await api.request('/auth/logout',{method:'POST'});
 assert.deepEqual(calls.map(c=>c[0]),['/api/auth/csrf','/api/auth/login','/api/auth/csrf','/api/auth/logout']);
 assert.equal(new Headers(calls[1][1].headers).get('X-CSRF'),'A');
 assert.equal(new Headers(calls[3][1].headers).get('X-CSRF'),'B');
});
test('failed mutation is NOT retried',async()=>{
 let writes=0;const api=createApi(async(p)=>{if(p.endsWith('/csrf'))return reply({headerName:'X-CSRF',token:'A'});writes++;throw new TypeError('offline')});
 await assert.rejects(()=>api.request('/example',{method:'POST'}));assert.equal(writes,1);
});
test('401 is preserved even with HTML error body',async()=>{
 const api=createApi(async()=>new Response('<html>error</html>',{status:401}));
 await assert.rejects(()=>api.request('/auth/me'),e=>e instanceof ApiError&&e.status===401);
});
test('204 has no JSON body',async()=>{
 const api=createApi(async(p)=>p.endsWith('/csrf')?reply({headerName:'X-CSRF',token:'A'}):reply(null,204));
 assert.equal(await api.request('/auth/logout',{method:'POST'}),undefined);
});
test('JSON content type is set only for JSON',async()=>{
 let headers;const api=createApi(async(p,o)=>{if(p.endsWith('/csrf'))return reply({headerName:'X-CSRF',token:'A'});headers=new Headers(o.headers);return reply({})});
 await api.request('/example',{method:'POST',body:JSON.stringify({a:1})});assert.equal(headers.get('Content-Type'),'application/json');
 await api.request('/example',{method:'POST',body:new FormData()});assert.equal(headers.has('Content-Type'),false);
});
