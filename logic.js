(function(root){
 const day=86400000;
 function dateKey(d=new Date()){return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
 function number(s){const [y,m,d]=s.split('-').map(Number);return Date.UTC(y,m-1,d)/day;}
 function effective(p){let n=number(p.expiry);if(p.opened&&p.afterDays)n=Math.min(n,number(p.opened)+Number(p.afterDays));return n;}
 function remaining(p,today=dateKey()){return effective(p)-number(today);}
 function message(p,n){return n<0?`${p.name}: Bu ürün bozulmuş olabilir. Ambalajdaki tarih veya açıldıktan sonraki tüketim süresi geçti.`:n===0?`${p.name}: Tüketim süresi bugün doluyor.`:`${p.name}: Tüketim süresinin dolmasına ${n} gün kaldı.`;}
 const api={dateKey,number,effective,remaining,message};if(typeof module!=='undefined')module.exports=api;else root.Taze=api;
})(typeof window==='undefined'?globalThis:window);
