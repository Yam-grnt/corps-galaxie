// Le corps galaxie — données du modèle : chaque nœud est un nuage de points dont certains s'ouvrent sur un autre nœud.
// Fichier généré à partir de la version web ; aucune dépendance au navigateur.
'use strict';
const MODELE=(()=>{
/* ───────── hasard déterministe et vecteurs ───────── */
let S=20261111;
const rnd=()=>{S=S+0x6D2B79F5|0;let t=Math.imul(S^S>>>15,1|S);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296};
const rs=()=>rnd()*2-1, gs=()=>(rnd()+rnd()+rnd()+rnd()-2)*1.73, TAU=Math.PI*2;
const add=(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]], sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]], mulS=(a,s)=>[a[0]*s,a[1]*s,a[2]*s];
const dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2], cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const len=a=>Math.hypot(a[0],a[1],a[2]), norm=a=>{const l=len(a)||1;return[a[0]/l,a[1]/l,a[2]/l]};
const lerp=(a,b,t)=>[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t], dist=(a,b)=>len(sub(a,b));
const dir=()=>{const z=rs(),a=rnd()*TAU,r=Math.sqrt(1-z*z);return[r*Math.cos(a),z,r*Math.sin(a)]};
const inBall=()=>mulS(dir(),Math.cbrt(rnd()));
const perp=ax=>{const d=dir();return norm(sub(d,mulS(ax,dot(d,ax))))};
const pickOf=a=>a[rnd()*a.length|0];

/* ───────── rotations (table partagée) ───────── */
const ROT=[new Float64Array([1,0,0,0,1,0,0,0,1])];
const rotCols=(x,y,z)=>{ROT.push(new Float64Array([x[0],y[0],z[0],x[1],y[1],z[1],x[2],y[2],z[2]]));return ROT.length-1};
function basis(y){const t=Math.abs(y[1])<.9?[0,1,0]:[1,0,0],x=norm(cross(t,y)),z0=cross(x,y),a=rnd()*TAU;
  const xr=add(mulS(x,Math.cos(a)),mulS(z0,Math.sin(a)));return[xr,y,cross(xr,y)]}
const aim=d=>{const b=basis(norm(d));return rotCols(b[0],b[1],b[2])};      // l'axe +y de l'enfant pointe vers d
const aimX=d=>{const b=basis(norm(d));return rotCols(b[1],b[2],b[0])};     // l'axe +x de l'enfant pointe vers d
for(let i=0;i<31;i++)aim(dir());
const RX_Y=rotCols([0,1,0],[-1,0,0],[0,0,1]);

/* ───────── nœuds : un nuage de points dont certains s'ouvrent sur un autre nœud ───────── */
const ALL=[];
const node=(name,desc,size,cat)=>{const n={name,desc,size,cat,sys:-1,p:[],k:[],ri:[],ci:[],sy:[],ph:[],kinds:[]};ALL.push(n);return n};
const hex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)/255),PAL=[[1,1,1]];let INK=0;
// état courant du pinceau : INK teinte les points sans enfant, TINT surcharge la teinte d'un point-enfant (0 : couleur de l'enfant),
// SYS est le système anatomique du point (null : celui de l'enfant, sinon celui du nœud), PH la phase le long d'un trajet (flux)
let TINT=0,SYS=null,PH=0;
const ink=h=>{PAL.push(hex(h));return PAL.length-1};
const bez=(a,m,b,t)=>lerp(lerp(a,m,t),lerp(m,b,t),t);
function put(n,p,c,r,rot){n.p.push(p[0],p[1],p[2]);n.sy.push(SYS);n.ph.push(PH);
  if(c){let ki=n.kinds.findIndex(q=>q.c===c&&q.r===r);if(ki<0){ki=n.kinds.length;n.kinds.push({c,r})}
    n.k.push(ki);n.ri.push(rot===undefined?1+(rnd()*31|0):rot);n.ci.push(TINT)}
  else{n.k.push(255);n.ri.push(0);n.ci.push(INK)}}
const fuzz=(n,count,sd,c=[0,0,0])=>{for(let i=0;i<count;i++)put(n,[c[0]+gs()*sd,c[1]+gs()*sd,c[2]+gs()*sd])};
const line=(n,a,b,count,j=.01,p0,p1)=>{for(let i=0;i<count;i++){const t=rnd(),p=lerp(a,b,t);if(p0!==undefined)PH=p0+(p1-p0)*t;put(n,[p[0]+gs()*j,p[1]+gs()*j,p[2]+gs()*j])}if(p0!==undefined)PH=0};
// phase = position le long d'un axe du nœud (0 : x, 1 : y), pour les nœuds traversés par un flux
const phAxe=(n,ax,sens=1)=>{for(let i=0;i<n.ph.length;i++)n.ph[i]=1.05+sens*n.p[3*i+ax]};
function seal(n){const N=n.k.length,idx=[...Array(N).keys()];
  for(let i=N-1;i>0;i--){const j=rnd()*(i+1)|0;[idx[i],idx[j]]=[idx[j],idx[i]]}
  const rOf=i=>n.k[i]===255?0:n.kinds[n.k[i]].r;
  const big=idx.filter(i=>rOf(i)>=.012).sort((a,b)=>rOf(b)-rOf(a)).slice(0,40),bs=new Set(big);
  const ord=big.concat(idx.filter(i=>!bs.has(i)));
  n.n=N;n.ns=big.length;n.P=new Float32Array(N*3);n.K=new Uint8Array(N);n.R=new Uint16Array(N);n.C=new Uint8Array(N);n.S=new Float32Array(N*2);   // S : [système, phase] par point
  ord.forEach((o,i)=>{n.P[i*3]=n.p[o*3];n.P[i*3+1]=n.p[o*3+1];n.P[i*3+2]=n.p[o*3+2];n.K[i]=n.k[o];n.R[i]=n.ri[o];n.C[i]=n.ci[o];
    const k=n.k[o],s=n.sy[o];n.S[2*i]=s!==null?s:k!==255&&n.kinds[k].c.sys>=0?n.kinds[k].c.sys:n.sys;n.S[2*i+1]=n.ph[o]});
  n.maxR=0;n.minR=1;n.kinds.forEach(q=>{n.maxR=Math.max(n.maxR,q.r);n.minR=Math.min(n.minR,q.r)});
  delete n.p;delete n.k;delete n.ri;delete n.ci;delete n.sy;delete n.ph}

/* ───────── particules et atomes ───────── */
const QU=node('Quark up','Particule élémentaire de charge +2/3. À ce jour, personne n\'a observé de structure plus petite à l\'intérieur : ici s\'arrête ce que la physique sait voir.',1e-18,'Particule élémentaire');
const QD=node('Quark down','Particule élémentaire de charge −1/3. Avec le quark up, il compose toute la matière de ton corps. On ne lui connaît aucune structure interne.',1e-18,'Particule élémentaire');
const ELEC=node('Électron','Particule élémentaire de charge négative, environ 1 800 fois plus légère qu\'un proton. Ce sont les électrons partagés entre atomes qui forment les liaisons chimiques.',1e-18,'Particule élémentaire');
[QU,QD,ELEC].forEach(q=>{fuzz(q,2600,.16);fuzz(q,1400,.4)});
function nucleon(name,desc,qs){const n=node(name,desc,1.7e-15,'Nucléon'),ps=[0,1,2].map(i=>[.42*Math.cos(i*TAU/3+.5),.42*Math.sin(i*TAU/3+.5),0]);
  ps.forEach((p,i)=>put(n,p,qs[i],.2));for(let i=0;i<3;i++)line(n,ps[i],ps[(i+1)%3],90,.04);fuzz(n,600,.3);return n}
const PROTON=nucleon('Proton','Deux quarks up et un quark down, tenus ensemble par les gluons (le nuage entre eux). Le nombre de protons décide de quel élément il s\'agit : 6 pour le carbone, 8 pour l\'oxygène.',[QU,QU,QD]);
const NEUTRON=nucleon('Neutron','Un quark up et deux quarks down. Sans charge électrique, il sert de colle dans le noyau : il empêche les protons, qui se repoussent, de le faire éclater.',[QU,QD,QD]);
function nucleus(nom,Z,Nn){const A=Z+Nn,n=node('Noyau '+nom,`Le cœur de l'atome : ${Z} proton${Z>1?'s':''}${Nn?` et ${Nn} neutrons`:''}, soudés par l'interaction forte. Il porte presque toute la masse dans un volume environ 100 000 fois plus étroit que l'atome.`,2.4e-15*Math.cbrt(A),'Noyau atomique');
  if(A===1){put(n,[0,0,0],PROTON,.6,0);fuzz(n,160,.45);return n}
  const R=.78,r=.6*R/Math.cbrt(A),ps=[];for(let i=0;i<A;i++)ps.push(mulS(inBall(),R-r));
  for(let it=0;it<60;it++){for(let i=0;i<A;i++)for(let j=0;j<i;j++){const d=sub(ps[i],ps[j]),l=len(d)||1e-3;
      if(l<2*r){const m=mulS(d,(2*r-l)/l/2);ps[i]=add(ps[i],m);ps[j]=sub(ps[j],m)}}
    ps.forEach((p,i)=>{const l=len(p);if(l>R-r)ps[i]=mulS(p,(R-r)/l)})}
  ps.forEach((p,i)=>put(n,p,i<Z?PROTON:NEUTRON,r));fuzz(n,200,.4);return n}
const ATOM={};
function atom(sym,nom,de,Z,Nn,shells,diam,desc){const n=node('Atome '+de+nom,desc,diam,'Atome · '+sym+' · '+Z+' électron'+(Z>1?'s':''));
  put(n,[0,0,0],nucleus(de+nom,Z,Nn),.035,0);
  shells.forEach((e,s)=>{const R=[.3,.52,.74,.92][s];for(let i=0;i<e;i++)put(n,mulS(dir(),R),ELEC,.016);
    for(let i=0;i<420+s*220;i++)put(n,mulS(dir(),R+gs()*.035))});
  ATOM[sym]=n}
atom('H','hydrogène',"d'",1,0,[1],1.1e-10,'Le plus simple des atomes : un proton, un électron. Il représente environ 62 % des atomes de ton corps, surtout dans l\'eau.');
atom('C','carbone','de ',6,6,[2,4],1.5e-10,'Le squelette de la vie. Il peut former quatre liaisons, ce qui permet les chaînes et les anneaux de toutes les molécules biologiques.');
atom('N','azote',"d'",7,7,[2,5],1.4e-10,'Présent dans chaque acide aminé et dans chaque base de l\'ADN. Sans azote, ni protéines ni gènes.');
atom('O','oxygène',"d'",8,8,[2,6],1.3e-10,'Il attire fortement les électrons. Environ 65 % de la masse de ton corps est de l\'oxygène, principalement sous forme d\'eau.');
atom('P','phosphore','de ',15,16,[2,8,5],2e-10,'L\'atome de l\'énergie et de l\'ossature : au centre des phosphates de l\'ADN, de l\'ATP et du minéral des os.');
atom('S','soufre','de ',16,16,[2,8,6],2e-10,'Il forme des ponts entre deux parties d\'une protéine et la maintient pliée. C\'est lui qui rend la kératine des cheveux solide.');
atom('Ca','calcium','de ',20,20,[2,8,8,2],3.6e-10,'Le métal le plus abondant du corps : 99 % est dans les os et les dents. Le reste déclenche la contraction des muscles et les signaux nerveux.');
atom('Fe','fer','de ',26,30,[2,8,14,2],2.5e-10,'Au centre de l\'hème, c\'est lui qui accroche l\'oxygène dans le sang. Ton corps en contient 3 à 4 grammes.');

/* ───────── petites molécules (coordonnées approchées, en ångströms) ───────── */
function mol(name,desc,size,at,cat,flip){const n=node(name,desc,size,cat||'Molécule');let c=[0,0,0];at.forEach(a=>{c=add(c,a[1])});c=mulS(c,1/at.length);
  const q=at.map(a=>{const p=sub(a[1],c);if(flip)p[1]=-p[1];return[a[0],p]});let mR=0;q.forEach(a=>{mR=Math.max(mR,len(a[1]))});
  const k=.95/(mR+.45);q.forEach(a=>put(n,mulS(a[1],k),ATOM[a[0]],(a[0]==='H'?.27:.38)*k));
  for(let i=0;i<q.length;i++)for(let j=0;j<i;j++){const a=q[i],b=q[j],d=dist(a[1],b[1]);
    const lim=(a[0]==='H'||b[0]==='H')?(a[0]===b[0]?0:1.25):(a[0]==='Fe'||b[0]==='Fe'||a[0]==='Ca'||b[0]==='Ca')?2.6:1.9;
    if(d<lim)line(n,mulS(a[1],k),mulS(b[1],k),9,.012)}
  return n}
const ring=(m,R,a0=0,c=[0,0,0])=>Array.from({length:m},(_,i)=>[c[0]+R*Math.cos(a0+i*TAU/m),c[1]+R*Math.sin(a0+i*TAU/m),c[2]]);
const out=(p,c,l,z=0)=>{const d=norm([p[0]-c[0],p[1]-c[1],0]);return[p[0]+d[0]*l,p[1]+d[1]*l,p[2]+z]};
const sh=(l,d)=>l.map(a=>[a[0],add(a[1],d)]);
function amino(a,p,c){const n=out(p,c,1.35),d=norm(sub(n,p));a.push(['N',n]);
  for(const s of[1,-1]){const an=s*1.05;a.push(['H',[n[0]+d[0]*Math.cos(an)-d[1]*Math.sin(an),n[1]+d[0]*Math.sin(an)+d[1]*Math.cos(an),0]])}}
function methyl(a,p,c){const m=out(p,c,1.5);a.push(['C',m],['H',out(m,p,1.05)],['H',[m[0],m[1],.95]],['H',[m[0],m[1],-.95]])}
function purine(g){const h=ring(6,1.4,Math.PI/6),c=[0,0,0],pc=[2.2,0,0],n7=[2.54,1.13,0],c8=[3.37,0,0],n9=[2.54,-1.13,0];
  const a=[['C',h[0]],['C',h[1]],['N',h[2]],['C',h[3]],['N',h[4]],['C',h[5]],['N',n7],['C',c8],['N',n9],['H',out(c8,pc,1.05)]];
  if(g){a.push(['O',out(h[1],c,1.25)],['H',out(h[2],c,1)]);amino(a,h[3],c)}else{amino(a,h[1],c);a.push(['H',out(h[3],c,1.05)])}
  return a}
function pyrimidine(t){const h=ring(6,1.4,Math.PI/6),c=[0,0,0];
  const a=[['N',h[0]],['C',h[1]],['N',h[2]],['C',h[3]],['C',h[4]],['C',h[5]],['O',out(h[1],c,1.25)],['H',out(h[5],c,1.05)]];
  if(t==='C'){amino(a,h[3],c);a.push(['H',out(h[4],c,1.05)])}
  else{a.push(['O',out(h[3],c,1.25)],['H',out(h[2],c,1)]);if(t==='T')methyl(a,h[4],c);else a.push(['H',out(h[4],c,1.05)])}
  return a}
function sugar(ribo){const v=ring(5,1.2,Math.PI/2),c=[0,0,0],a=[['O',v[0]],['C',v[1]],['C',v[2]],['C',v[3]],['C',v[4]]];
  const c5=out(v[4],c,1.5,.5),o3=out(v[3],c,1.4);a.push(['C',c5],['O',add(c5,[1.1,.6,-.4])],['O',o3],['H',out(o3,v[3],.95)]);
  [1,2,3,4].forEach(i=>a.push(['H',[v[i][0],v[i][1],i%2?1.05:-1.05]]));
  if(ribo){const o2=out(v[2],c,1.4,.3);a.push(['O',o2],['H',out(o2,v[2],.95)])}else a.push(['H',out(v[2],c,1.05)]);
  return a}
const phos=(p=[0,0,0])=>[['P',p],['O',add(p,[0,1.5,0])],['O',add(p,[0,-.8,1.25])],['O',add(p,[0,-.8,-1.25])],['O',add(p,[1.4,-.1,0])],['O',add(p,[-1.4,-.1,0])]];
const EAU=mol('Eau (H₂O)','Un atome d\'oxygène et deux d\'hydrogène. Environ 60 % de ton corps : presque toutes les réactions de la vie se déroulent dans l\'eau.',2.8e-10,[['O',[0,0,0]],['H',[.96,0,0]],['H',[-.24,.93,0]]]);
const O2=mol('Dioxygène (O₂)','Deux atomes d\'oxygène liés. Inspiré par les poumons, transporté par le sang, il sert aux mitochondries à extraire l\'énergie du sucre.',3e-10,[['O',[-.6,0,0]],['O',[.6,0,0]]]);
const CO2=mol('Dioxyde de carbone (CO₂)','Le déchet de la respiration des cellules. Le sang le ramène aux poumons, qui le rejettent à chaque expiration.',3.3e-10,[['O',[-1.16,0,0]],['C',[0,0,0]],['O',[1.16,0,0]]]);
const BA=mol('Adénine (A)','Une des quatre lettres du code génétique. Dans l\'ADN, elle s\'apparie toujours avec la thymine ; dans l\'ARN, avec l\'uracile.',7e-10,purine(false),'Base azotée');
const BG=mol('Guanine (G)','Une des quatre lettres du code génétique. Elle s\'apparie avec la cytosine par trois liaisons hydrogène, une paire plus solide que A–T.',7e-10,purine(true),'Base azotée');
const BC=mol('Cytosine (C)','Une des quatre lettres du code génétique. Elle fait face à la guanine sur le brin opposé.',6e-10,pyrimidine('C'),'Base azotée');
const BT=mol('Thymine (T)','Une des quatre lettres de l\'ADN, partenaire de l\'adénine. Dans l\'ARN, elle est remplacée par l\'uracile.',6e-10,pyrimidine('T'),'Base azotée');
const BU=mol('Uracile (U)','La lettre propre à l\'ARN : elle prend la place de la thymine et s\'apparie avec l\'adénine.',6e-10,pyrimidine('U'),'Base azotée');
const DESOXY=mol('Désoxyribose','Le sucre à cinq carbones de l\'ADN. Il lui manque un oxygène par rapport au ribose, d\'où le « désoxy » : ce détail rend l\'ADN plus stable que l\'ARN.',6e-10,sugar(false),'Sucre');
const RIBOSE=mol('Ribose','Le sucre à cinq carbones de l\'ARN et de l\'ATP.',6e-10,sugar(true),'Sucre');
const PHOS=mol('Groupe phosphate','Un atome de phosphore entouré d\'oxygènes. Il relie les sucres entre eux pour former le squelette de l\'ADN, et stocke l\'énergie dans l\'ATP.',5e-10,phos().slice(0,5));
const GLUCOSE=(()=>{const h=ring(6,1.45,0),c=[0,0,0],a=[['O',h[0]]];for(let i=1;i<6;i++)a.push(['C',h[i]],['H',[h[i][0],h[i][1],i%2?1.05:-1.05]]);
  for(let i=1;i<5;i++){const o=out(h[i],c,1.4);a.push(['O',o],['H',out(o,h[i],.95)])}
  const c6=out(h[5],c,1.5),o6=add(c6,[.9,-1,.3]);a.push(['C',c6],['O',o6],['H',add(o6,[.9,.2,0])],['H',[c6[0],c6[1],1]]);
  return mol('Glucose','Le sucre que le sang distribue à toutes les cellules. Les mitochondries le brûlent avec l\'oxygène pour fabriquer de l\'ATP.',9e-10,a,'Sucre')})();
const ATP=(()=>{let a=sh(purine(false),[-5.08,1.8,0]).concat(sugar(true));[4.9,7.7,10.5].forEach(x=>{a=a.concat(phos([x,1.3,0]).slice(0,5))});
  return mol('ATP','Adénosine triphosphate : la pile rechargeable de la cellule. Casser la liaison du dernier phosphate libère l\'énergie de presque tout ce que tu fais. Tu en recycles environ ton poids chaque jour.',1.6e-9,a)})();
function aminoAcid(name,desc,side){const a=[['N',[-1.25,.35,0]],['C',[0,0,0]],['C',[1.25,.6,0]],['O',[1.35,1.85,0]],['O',[2.3,-.15,0]],['H',[-1.3,1.35,0]],['H',[-2.1,-.15,0]],['H',[0,-.4,-1]],['H',[3.1,.35,0]]];
  return mol(name,desc,7e-10,a.concat(side),'Acide aminé')}
const CB=[0,-1.2,.85],AA=[
  aminoAcid('Glycine','Le plus petit des 20 acides aminés. Sa petite taille permet aux chaînes de se serrer : un tiers du collagène est de la glycine.',[['H',[0,-.75,.75]]]),
  aminoAcid('Alanine','Un acide aminé simple, avec un groupe méthyle pour chaîne latérale. Une brique courante des protéines.',[['C',CB],['H',add(CB,[1,-.3,.3])],['H',add(CB,[-1,-.3,.3])],['H',add(CB,[0,-.5,1])]]),
  aminoAcid('Cystéine','Acide aminé porteur d\'un atome de soufre. Deux cystéines peuvent se souder et verrouiller la forme d\'une protéine.',[['C',CB],['S',add(CB,[0,-1.5,.9])],['H',add(CB,[1,-.2,-.2])],['H',add(CB,[0,-2.4,0])]]),
  aminoAcid('Sérine','Acide aminé avec un groupe –OH qui aime l\'eau. C\'est souvent là que la cellule accroche un phosphate pour activer ou éteindre une protéine.',[['C',CB],['O',add(CB,[0,-1.2,.8])],['H',add(CB,[1,-.2,-.2])],['H',add(CB,[0,-2,.4])]])];
const GLU=aminoAcid('Glutamate','Un acide aminé, mais aussi le principal messager excitateur du cerveau : libéré dans la synapse, il transmet le signal au neurone suivant.',[['C',CB],['C',add(CB,[0,-1.3,.8])],['C',add(CB,[0,-2.6,1.6])],['O',add(CB,[1.1,-3,2])],['O',add(CB,[-1.1,-3.2,1.8])]]);
AA.push(GLU);
function lipid(flip){const a=phos([0,6.5,0]).slice(0,4).concat([['O',[0,5.2,0]],['N',[0,9.3,0]],['C',[0,8,0]],['C',[1.3,9.9,0]],['C',[-1.3,9.9,0]],['C',[-1.2,4.4,0]],['C',[0,4,0]],['C',[1.2,4.4,0]]]);
  for(const s of[-1,1])for(let i=0;i<14;i++){const p=[s*1.2+(i%2?.45:-.45)*s,3.1-i*1.25,0];a.push(['C',p],['H',add(p,[0,0,.95])],['H',add(p,[0,0,-.95])])}
  return mol('Phospholipide','Une tête qui aime l\'eau (phosphate) et deux queues grasses qui la fuient. Mis ensemble, ils s\'alignent tout seuls en double couche : c\'est la membrane.',2.6e-9,a,'Lipide',flip)}
const LIPU=lipid(false),LIPD=lipid(true);
const HEME=(()=>{const a=[['Fe',[0,0,0]]],P=(r,an)=>[r*Math.cos(an),r*Math.sin(an),0];
  for(let i=0;i<4;i++){const an=i*TAU/4;a.push(['N',P(2,an)],['C',P(2.9,an+.39)],['C',P(2.9,an-.39)],['C',P(4.2,an+.16)],['C',P(4.2,an-.16)],['C',P(3.4,an+TAU/8)],['H',P(4.45,an+TAU/8)])}
  return mol('Hème','Un anneau plat avec un atome de fer au centre. C\'est le fer qui retient une molécule d\'oxygène, et qui donne au sang sa couleur rouge.',1e-9,a,'Groupe prosthétique')})();
const APATITE=(()=>{let a=[['O',[0,0,0]],['H',[0,0,.95]]];for(let i=0;i<6;i++){const an=i*TAU/6;a=a.concat(phos([4.1*Math.cos(an),4.1*Math.sin(an),i%2?1.2:-1.2]).slice(0,5))}
  for(let i=0;i<3;i++){const an=i*TAU/3+.5;a.push(['Ca',[2*Math.cos(an),2*Math.sin(an),0]])}
  for(let i=0;i<6;i++){const an=i*TAU/6+.52;a.push(['Ca',[6.3*Math.cos(an),6.3*Math.sin(an),0]])}
  return mol('Hydroxyapatite','Le minéral de l\'os : calcium et phosphate rangés en cristal. Il donne à l\'os sa dureté, le collagène lui donne sa souplesse.',1.6e-9,a,'Minéral')})();

/* ───────── macromolécules ───────── */
const ADN=node('ADN','La double hélice : deux brins de sucres et de phosphates enroulés, reliés par des paires de bases (A–T, G–C). L\'ordre des bases est le texte de tes gènes. Chaque cellule en contient environ 2 mètres.',7e-9,'Acide nucléique');
(()=>{const bp=20,P=(a,y,r)=>[r*Math.cos(a),y,r*Math.sin(a)];
  for(let j=0;j<bp;j++){const y=-.86+j*1.72/(bp-1),a=j*.63,s1=P(a,y,.36),s2=P(a+2.3,y,.36),pr=pickOf([[BA,BT],[BT,BA],[BG,BC],[BC,BG]]);
    put(ADN,s1,DESOXY,.04);put(ADN,s2,DESOXY,.04);put(ADN,P(a+.32,y+.045,.41),PHOS,.03);put(ADN,P(a+2.62,y+.045,.41),PHOS,.03);
    const d=norm(sub(s2,s1)),R=rotCols(d,cross([0,1,0],d),[0,1,0]);
    put(ADN,lerp(s1,s2,.3),pr[0],.07,R);put(ADN,lerp(s1,s2,.7),pr[1],.07,R);line(ADN,lerp(s1,s2,.42),lerp(s1,s2,.58),7,.006)}
  for(let i=0;i<1100;i++){const t=rnd(),a=t*(bp-1)*.63+(i%2?2.3:0);put(ADN,P(a,-.86+t*1.72+gs()*.01,.37+gs()*.012))}})();
const ARN=node('ARN','Une copie de travail d\'un gène, sur un seul brin. L\'ARN messager quitte le noyau et porte la recette d\'une protéine jusqu\'aux ribosomes. Il utilise l\'uracile à la place de la thymine.',1.2e-8,'Acide nucléique');
(()=>{const f=t=>[.42*Math.sin(5*t)+.14*Math.sin(13*t),1.7*t-.85,.38*Math.cos(4*t)+.1*Math.sin(11*t)];
  for(let j=0;j<32;j++){const t=j/31,p=f(t),q=f(t+.016),d=perp(norm(sub(q,p)));
    put(ARN,p,RIBOSE,.04);put(ARN,q,PHOS,.03);put(ARN,add(p,mulS(d,.1)),pickOf([BA,BU,BG,BC]),.06)}
  for(let i=0;i<700;i++){const p=f(rnd());put(ARN,[p[0]+gs()*.012,p[1]+gs()*.012,p[2]+gs()*.012])}})();
function fold(n,count,lobes,r){const per=Math.ceil(count/lobes.length);
  lobes.forEach(L=>{let p=add(L,mulS(inBall(),L[3]*.5)),d=dir(),prev=null;
    for(let i=0;i<per;i++){d=norm(add(d,mulS(dir(),.9)));let q=add(p,mulS(d,r*1.7));
      if(dist(q,L)>L[3]){d=norm(add(sub(L,p),mulS(dir(),L[3]*.6)));q=add(p,mulS(d,r*1.7))}
      p=q;put(n,p,pickOf(AA),r);if(prev)line(n,prev,p,3,.004);prev=p}})}
function protein(name,desc,size,lobes,count,r){const n=node(name,desc,size,'Protéine');fold(n,count,lobes,r||.05);return n}
function fiber(name,desc,size,strands,R,twist){const n=node(name,desc,size,'Protéine');
  for(let s=0;s<strands;s++){let prev=null;for(let i=0;i<70;i++){const y=-.92+i*1.84/69,a=s*TAU/strands+y*twist,p=[R*Math.cos(a)+.03*Math.cos(i*1.75),y,R*Math.sin(a)+.03*Math.sin(i*1.75)];
    put(n,p,pickOf(AA),.035);if(prev)line(n,prev,p,3,.004);prev=p}}return n}
const PROT=protein('Protéine','Une chaîne d\'acides aminés repliée sur elle-même. Sa forme fait sa fonction : les protéines coupent, transportent, construisent et signalent. Ton corps en fabrique des dizaines de milliers de sortes.',5e-9,[[0,0,0,.72]],170);
const HISTONE=protein('Histone','La bobine de l\'ADN. Huit histones forment un cœur autour duquel l\'ADN s\'enroule, ce qui permet de ranger 2 mètres de fil dans un noyau de quelques micromètres.',3e-9,[[0,0,0,.7]],120);
const HEMO=protein('Hémoglobine','Quatre chaînes, chacune portant un hème. Elle charge l\'oxygène dans les poumons et le dépose dans les tissus. Un globule rouge en contient environ 270 millions.',6.5e-9,[[.36,.36,.2,.36],[-.36,-.36,.2,.36],[.36,-.36,-.2,.36],[-.36,.36,-.2,.36]],200,.045);
[[.36,.36,.2],[-.36,-.36,.2],[.36,-.36,-.2],[-.36,.36,-.2]].forEach(p=>put(HEMO,p,HEME,.1));
const ATPSYN=protein('ATP synthase','Une turbine moléculaire. Le flux de protons à travers la membrane la fait tourner, et chaque tour fabrique trois ATP. Elle tourne à plus de 100 tours par seconde.',2e-8,[[0,.45,0,.42],[0,-.05,0,.16],[0,-.5,0,.3],[.3,.2,0,.14]],240,.04);
const ACTINE=protein('Actine','Un filament fin fait de billes d\'actine enroulées en hélice. Dans le muscle, la myosine s\'y accroche et tire dessus.',4e-8,Array.from({length:10},(_,i)=>[.13*Math.cos(i*2.9),-.8+i*.178,.13*Math.sin(i*2.9),.13]),220,.035);
const MYOSINE=protein('Myosine','Le moteur du muscle : une longue tige et deux têtes. Chaque tête agrippe l\'actine, bascule, lâche et recommence, en brûlant un ATP par pas.',1.6e-7,[[0,-.75,0,.07],[0,-.5,0,.07],[0,-.25,0,.07],[0,0,0,.07],[0,.25,0,.07],[.05,.5,0,.07],[.18,.72,0,.17],[-.18,.72,0,.17]],230,.03);
const COLLAGENE=fiber('Collagène','Trois chaînes tressées en corde. C\'est la protéine la plus abondante du corps : elle donne leur résistance à la peau, aux tendons et aux os.',3e-8,3,.11,7);
const KERATINE=fiber('Kératine','Deux hélices enroulées l\'une sur l\'autre, verrouillées par des ponts de soufre. Elle rend l\'épiderme étanche et forme les cheveux et les ongles.',2e-8,2,.09,5);
const ANTICORPS=protein('Anticorps','Une protéine en Y. Les deux bras reconnaissent un intrus précis (virus, bactérie) et s\'y fixent ; le pied appelle le reste du système immunitaire.',1.2e-8,[[0,-.6,0,.2],[0,-.25,0,.2],[.25,.15,0,.2],[.52,.5,0,.2],[-.25,.15,0,.2],[-.52,.5,0,.2]],240,.04);
const CANAL=protein('Canal ionique','Un tunnel à travers la membrane. Il s\'ouvre et se ferme pour laisser passer des ions (sodium, potassium, calcium) : c\'est la base de l\'influx nerveux.',8e-9,[0,1,2,3].map(i=>[.36*Math.cos(i*TAU/4),0,.36*Math.sin(i*TAU/4),.3]).concat([0,1,2,3].map(i=>[.36*Math.cos(i*TAU/4),.5,.36*Math.sin(i*TAU/4),.26]),[0,1,2,3].map(i=>[.36*Math.cos(i*TAU/4),-.5,.36*Math.sin(i*TAU/4),.26])),300,.04);
const RHODO=protein('Rhodopsine','Le capteur de lumière des bâtonnets. Un seul photon suffit à changer sa forme et à déclencher un signal vers le cerveau.',7e-9,Array.from({length:14},(_,i)=>[.38*Math.cos((i>>1)*TAU/7),i%2?.4:-.4,.38*Math.sin((i>>1)*TAU/7),.2]),260,.04);
const ENZYME=protein('Enzyme','Une protéine qui accélère une réaction chimique, souvent des millions de fois. Chaque enzyme ne reconnaît que sa cible, comme une serrure sa clé.',6e-9,[[.2,0,0,.55],[-.3,.1,0,.45]],190);
const ARNPOL=protein('ARN polymérase','L\'enzyme qui lit un gène. Elle ouvre la double hélice et recopie un brin d\'ADN en ARN, lettre par lettre.',1.5e-8,[[0,.3,0,.5],[.3,-.3,0,.4],[-.3,-.3,0,.4]],230,.045);
const TUBULINE=protein('Tubuline','La brique des microtubules. Elle s\'assemble par paires, puis en longues files qui forment un tube creux.',8e-9,[[0,.4,0,.42],[0,-.4,0,.42]],160);
const PORE=protein('Pore nucléaire','Une porte dans l\'enveloppe du noyau. L\'ARN messager sort par là ; les protéines utiles au noyau y entrent. Chaque noyau en compte des milliers.',1.2e-7,Array.from({length:8},(_,i)=>[.55*Math.cos(i*TAU/8),0,.55*Math.sin(i*TAU/8),.22]),280,.04);

const MEMB=node('Membrane cellulaire','Une double couche de phospholipides, épaisse de 5 nanomètres, qui sépare l\'intérieur de l\'extérieur. Des protéines y flottent et contrôlent ce qui entre et sort.',3.6e-8,'Structure');
(()=>{const ch=[[.3,.2],[-.45,-.1],[.05,-.5]];
  for(let i=-7;i<=7;i++)for(let j=-7;j<=7;j++){const x=i*.125+(j%2?.06:0)+gs()*.012,z=j*.125+gs()*.012;if(x*x+z*z>.82)continue;
    if(ch.some(c=>Math.hypot(x-c[0],z-c[1])<.15))continue;const y=.05*Math.sin(3*x+1)+.04*Math.sin(2.5*z);
    put(MEMB,[x,y+.072,z],LIPU,.07,0);put(MEMB,[x,y-.072,z],LIPD,.07,0)}
  ch.forEach(c=>put(MEMB,[c[0],.05*Math.sin(3*c[0]+1),c[1]],CANAL,.16,0));
  for(let i=0;i<160;i++){const x=rs()*.85,z=rs()*.85,s=i%2?1:-1;put(MEMB,[x,s*(.22+rnd()*.3),z],EAU,.012)}})();

/* ───────── organites ───────── */
const NUCLEOSOME=node('Nucléosome','L\'ADN fait presque deux tours autour d\'un cœur de huit histones, comme du fil sur une bobine. C\'est le premier niveau de rangement du génome.',1.1e-8,'Structure de la chromatine');
(()=>{for(let i=0;i<8;i++){const a=i*TAU/4+(i>3?.78:0);put(NUCLEOSOME,[.2*Math.cos(a),i>3?.13:-.13,.2*Math.sin(a)],HISTONE,.17)}
  const f=t=>[.62*Math.cos(t),-.2+.4*t/10.7,.62*Math.sin(t)];
  for(let i=0;i<=15;i++){const t=i*10.7/15,p=f(t);put(NUCLEOSOME,p,ADN,.13,aim(sub(f(t+.1),p)))}
  for(const e of[0,10.7]){const p=f(e),d=mulS(norm(sub(f(e+.1),p)),e?1:-1);for(let i=1;i<3;i++)put(NUCLEOSOME,add(p,mulS(d,i*.2)),ADN,.13,aim(d))}})();
function walk(count,step,R,avoid){const ps=[];let p=mulS(inBall(),R*.7),d=dir();
  for(let i=0;i<count;i++){d=norm(add(d,mulS(dir(),.6)));let q=add(p,mulS(d,step));
    if(len(q)>R||(avoid&&dist(q,avoid)<avoid[3])){d=norm(add(mulS(avoid&&dist(q,avoid)<avoid[3]?sub(q,avoid):mulS(p,-1),1),mulS(dir(),.5)));q=add(p,mulS(d,step))}
    p=q;ps.push(p)}return ps}
const CHROMATINE=node('Fibre de chromatine','L\'ADN enroulé sur ses nucléosomes, comme des perles sur un fil, puis replié sur lui-même. Selon qu\'elle est serrée ou relâchée, les gènes sont éteints ou lisibles.',2e-7,'Chromosome déroulé');
(()=>{const ps=walk(46,.15,.82);ps.forEach((p,i)=>{put(CHROMATINE,p,NUCLEOSOME,.055);
  if(i){const a=ps[i-1];line(CHROMATINE,a,p,10,.006);put(CHROMATINE,lerp(a,p,.5),ADN,.03,aim(sub(p,a)))}})})();
const RIBO=node('Ribosome','L\'atelier d\'assemblage des protéines. Il lit l\'ARN messager trois lettres à la fois et accroche les acides aminés dans l\'ordre, environ 5 par seconde.',2.5e-8,'Organite');
(()=>{const L=[[0,.2,0,.55],[0,-.48,0,.36]];L.forEach((l,li)=>{for(let i=0;i<(li?10:22);i++)put(RIBO,add(l,mulS(inBall(),l[3]*.8)),ARN,.13);
    for(let i=0;i<(li?16:34);i++)put(RIBO,add(l,mulS(inBall(),l[3]*.9)),PROT,.07);for(let i=0;i<(li?250:500);i++)put(RIBO,add(l,mulS(dir(),l[3]*(.85+rnd()*.15))))});
  line(RIBO,[-.95,-.17,0],[.95,-.17,0],160,.012);[-.7,0,.7].forEach(x=>put(RIBO,[x,-.17,0],ARN,.1,aimX([1,0,0])));put(RIBO,[.1,.86,0],PROT,.1)})();
const NUCLEOLE=node('Nucléole','La zone dense du noyau où se fabriquent les ribosomes : l\'ARN ribosomique y est copié puis assemblé avec des protéines.',1.5e-6,'Région du noyau');
(()=>{fuzz(NUCLEOLE,700,.33);for(let i=0;i<110;i++)put(NUCLEOLE,mulS([gs(),gs(),gs()],.3),ARN,.04);
  for(let i=0;i<60;i++)put(NUCLEOLE,mulS(dir(),.55+rnd()*.3),RIBO,.035);for(let i=0;i<40;i++)put(NUCLEOLE,mulS(inBall(),.8),ARNPOL,.02)})();
const NOYAU=node('Noyau','La bibliothèque de la cellule. Il abrite l\'ADN : 46 chromosomes, environ 3 milliards de paires de bases. Les gènes y sont recopiés en ARN avant de partir vers le cytoplasme.',6e-6,'Organite');
(()=>{const nl=[.28,.18,.1,.24];put(NOYAU,nl,NUCLEOLE,.2);
  for(let i=0;i<1100;i++)put(NOYAU,mulS(dir(),i%2?.93:.96));for(let i=0;i<60;i++){const d=dir();put(NOYAU,mulS(d,.945),PORE,.03,aim(d))}
  for(let c=0;c<16;c++){const ps=walk(42,.075,.86,nl);ps.forEach((p,i)=>{put(NOYAU,p,CHROMATINE,.036);if(i)line(NOYAU,ps[i-1],p,3,.01)})}
  for(let i=0;i<26;i++)put(NOYAU,mulS(inBall(),.85),ARN,.02);for(let i=0;i<36;i++)put(NOYAU,mulS(inBall(),.85),ARNPOL,.012)})();
const MITO=node('Mitochondrie','La centrale énergétique. Elle brûle le sucre et les graisses avec l\'oxygène pour recharger l\'ATP. Elle possède son propre petit ADN, hérité de ta mère.',2e-6,'Organite');
(()=>{const hl=.55,R=.36,surf=()=>{const t=rnd();if(t<.7){const x=rs()*hl,a=rnd()*TAU;return[x,R*Math.cos(a),R*Math.sin(a)]}const d=dir();return[(d[0]>0?hl:-hl)+d[0]*R,d[1]*R,d[2]*R]};
  for(let i=0;i<900;i++){const p=surf();i%14?put(MITO,p):put(MITO,p,MEMB,.035)}
  for(let k=-5;k<=5;k++){const x=k*.1,top=k%2?1:-1;for(let i=0;i<120;i++){const y=top*(R*.92-rnd()*R*1.35),z=rs()*R*.85;if(y*y+z*z>R*R*.8)continue;
      const p=[x+.012*gs(),y,z];rnd()<.16?put(MITO,p,ATPSYN,.017,aim([k%2?1:-1,0,0])):put(MITO,p)}}
  const inn=()=>{const x=rs()*hl,r=R*.85*Math.sqrt(rnd()),a=rnd()*TAU;return[x,r*Math.cos(a),r*Math.sin(a)]};
  for(let i=0;i<110;i++)put(MITO,inn(),ATP,.006);for(let i=0;i<5;i++)put(MITO,inn(),ADN,.035);for(let i=0;i<22;i++)put(MITO,inn(),RIBO,.013);
  for(let i=0;i<50;i++)put(MITO,inn(),O2,.004);for(let i=0;i<30;i++)put(MITO,inn(),ENZYME,.008);for(let i=0;i<80;i++)put(MITO,inn(),EAU,.003)})();
const RE=node('Réticulum endoplasmique','Un réseau de membranes repliées, collé au noyau. Sa partie rugueuse, couverte de ribosomes, fabrique les protéines destinées à sortir de la cellule ; sa partie lisse fabrique les lipides.',3e-6,'Organite');
(()=>{for(let s=0;s<6;s++)for(let i=0;i<280;i++){const x=rs()*.82,z=rs()*.62;if(x*x/.67+z*z/.38>1)continue;
    const p=[x,(s-2.5)*.16+.05*Math.sin(4*x+s)+.03*Math.sin(5*z),z],u=rnd();u<.13?put(RE,add(p,[0,.02,0]),RIBO,.016):u<.18?put(RE,p,MEMB,.03):u<.21?put(RE,p,PROT,.012):put(RE,p)}})();
function vesicle(name,desc,size,cargo,rC,nC,rM,nM){const n=node(name,desc,size,'Organite');
  for(let i=0;i<nM;i++){const d=dir();put(n,mulS(d,.8),MEMB,rM,aim(d))}for(let i=0;i<500;i++)put(n,mulS(dir(),.8+gs()*.01));
  for(let i=0;i<nC;i++)put(n,mulS(inBall(),.68),cargo,rC);return n}
const VESICULE=vesicle('Vésicule','Une bulle de membrane qui transporte des protéines d\'un compartiment à l\'autre, ou les libère à l\'extérieur de la cellule.',1e-7,PROT,.07,45,.17,70);
const LYSOSOME=vesicle('Lysosome','L\'estomac de la cellule : un sac acide rempli d\'enzymes qui découpent les déchets et les composants usés pour les recycler.',5e-7,ENZYME,.03,160,.05,220);
const VESSYN=vesicle('Vésicule synaptique','Un petit sac de glutamate prêt à l\'emploi. Quand le signal électrique arrive au bout de l\'axone, elle fusionne avec la membrane et libère son contenu vers le neurone suivant.',4e-8,GLU,.04,220,.22,50);
const GOLGI=node('Appareil de Golgi','Le centre de tri. Les protéines venues du réticulum y sont retouchées, étiquetées, puis emballées dans des vésicules vers leur destination.',2e-6,'Organite');
(()=>{for(let s=0;s<5;s++){const R=.72-s*.05;for(let i=0;i<300;i++){const r=R*Math.sqrt(rnd()),a=rnd()*TAU,x=r*Math.cos(a),z=r*Math.sin(a)*.7,p=[x,(s-2)*.14+.3*(x*x+z*z),z];rnd()<.07?put(GOLGI,p,MEMB,.03):put(GOLGI,p)}}
  for(let i=0;i<16;i++){const a=rnd()*TAU;put(GOLGI,[.85*Math.cos(a),rs()*.35+.2,.6*Math.sin(a)],VESICULE,.06)}})();
const MICROTUBULE=node('Microtubule','Un tube creux fait de tubuline. Il sert de charpente à la cellule et de rail : des moteurs moléculaires y transportent vésicules et organites.',1.2e-7,'Cytosquelette');
(()=>{for(let k=0;k<13;k++)for(let i=0;i<19;i++){const a=k*TAU/13;put(MICROTUBULE,[.24*Math.cos(a),-.9+i*.1+k*.008,.24*Math.sin(a)],TUBULINE,.052)}})();

/* ───────── cellules ───────── */
function blob(R=.85,fy=1,b=.07){const a=rnd()*6,c=rnd()*6,rad=d=>R*(1+b*Math.sin(3*d[0]+a)+b*Math.sin(4*d[1]+c)+b*.6*Math.sin(5*d[2]+a));
  return{inside(){const d=dir(),r=rad(d)*Math.cbrt(rnd())*.96;return[d[0]*r,d[1]*r*fy,d[2]*r]},surface(){const d=dir(),r=rad(d);return[d[0]*r,d[1]*r*fy,d[2]*r]}}}
function tubes(soma,segs,wS){const w=segs.map(s=>dist(s.a,s.b)*(s.ra+s.rb)+1e-4),tot=w.reduce((a,b)=>a+b,0);
  const sample=surf=>{if(soma&&rnd()<wS)return add(soma,mulS(dir(),soma[3]*(surf?1:Math.cbrt(rnd()))));
    let u=rnd()*tot,i=0;while(i<segs.length-1&&u>w[i]){u-=w[i];i++}
    const s=segs[i],t=rnd(),ax=norm(sub(s.b,s.a));return add(lerp(s.a,s.b,t),mulS(perp(ax),(s.ra+(s.rb-s.ra)*t)*(surf?1:Math.sqrt(rnd()))))};
  return{inside:()=>sample(false),surface:()=>sample(true)}}
function grow(segs,p,d,l,r,depth,tips){for(let i=0;i<3;i++){d=norm(add(d,mulS(dir(),.3)));const q=add(p,mulS(d,l/3));if(len(q)>.95){tips.push(p);return}
    segs.push({a:p,b:q,ra:r,rb:r*.86});p=q;r*=.86}
  if(depth>0)for(let i=0;i<2;i++)grow(segs,p,norm(add(d,mulS(dir(),.75))),l*.72,r,depth-1,tips);else tips.push(p)}
function fillCell(n,S,o){o=Object.assign({mito:22,ribo:130,nucR:.27,nuc:[.08,.05,0],re:1,golgi:1,lyso:8,ves:10,mt:8,prot:150,memb:.2,surf:850,small:1},o);
  const nuc=o.nucR?[o.nuc[0],o.nuc[1],o.nuc[2],o.nucR]:null;
  const free=m=>{for(let t=0;t<40;t++){const p=S.inside();if(!nuc||dist(p,nuc)>nuc[3]+m)return p}return S.inside()};
  if(nuc)put(n,nuc,NOYAU,o.nucR);
  for(let i=0;i<o.surf;i++){const p=S.surface();rnd()<o.memb?put(n,p,MEMB,.022):put(n,p)}
  if(nuc&&o.re){const d=dir();put(n,add(nuc,mulS(d,nuc[3]+.13)),RE,.16);put(n,add(nuc,mulS(d,-nuc[3]-.1)),RE,.12)}
  if(nuc&&o.golgi){const d=perp([0,1,0]);put(n,add(nuc,mulS(d,nuc[3]+.13)),GOLGI,.11)}
  const many=(c,r,k,m=r)=>{for(let i=0;i<k;i++)put(n,free(m),c,r)};
  many(MITO,.06,o.mito);many(LYSOSOME,.03,o.lyso);many(VESICULE,.022,o.ves);many(RIBO,.011,o.ribo);many(MICROTUBULE,.08,o.mt,.02);many(PROT,.007,o.prot);
  many(ATP,.0035,70*o.small);many(GLUCOSE,.0035,40*o.small);many(EAU,.0025,180*o.small);many(ARN,.018,nuc?14:0);many(ENZYME,.007,30*o.small);
  return free}
const cellNode=(name,desc,size)=>node(name,desc,size,'Cellule');
const NEURONE=cellNode('Neurone','La cellule qui pense. Ses dendrites (les branches) reçoivent les signaux, son long axone les envoie plus loin. Ton cerveau en compte environ 86 milliards, reliés par des milliers de milliards de synapses.',1.2e-4);
(()=>{const soma=[0,.2,0,.2],segs=[],tips=[],ax=[];for(let i=0;i<6;i++){const d=norm(add(dir(),[0,.5,0]));grow(segs,add(soma,mulS(d,.17)),d,.34,.045,2,tips)}
  grow(segs,[0,.02,0],[0,-1,0],.7,.04,1,ax);fillCell(NEURONE,tubes(soma,segs,.4),{nuc:[0,.2,0],nucR:.11,surf:1500,mito:30,mt:14});
  ax.forEach(p=>{for(let i=0;i<7;i++)put(NEURONE,add(p,mulS(inBall(),.05)),VESSYN,.014)});tips.forEach(p=>put(NEURONE,p,CANAL,.012))})();
const ASTRO=cellNode('Astrocyte','Cellule en étoile qui entoure les neurones. Elle les nourrit, nettoie les messagers chimiques après usage et participe à la barrière entre le sang et le cerveau.',6e-5);
(()=>{const soma=[0,0,0,.2],segs=[],tips=[];for(let i=0;i<11;i++){const d=dir();grow(segs,mulS(d,.16),d,.42,.04,1,tips)}fillCell(ASTRO,tubes(soma,segs,.45),{nuc:[0,0,0],nucR:.12,surf:1300})})();
const OSTEO=cellNode('Ostéocyte','Une cellule emmurée dans l\'os qu\'elle a construit. Ses fins prolongements la relient à ses voisines : ensemble, elles sentent les contraintes et commandent la réparation de l\'os.',3e-5);
(()=>{const soma=[0,0,0,.3],segs=[],tips=[];for(let i=0;i<16;i++){const d=dir();grow(segs,mulS(d,.26),d,.6,.028,0,tips)}fillCell(OSTEO,tubes(soma,segs,.6),{nuc:[0,0,0],nucR:.17,surf:1300,mito:12})})();
const RBC=cellNode('Globule rouge','Un disque creusé au centre, sans noyau ni organites : tout l\'espace sert à l\'hémoglobine. Il vit 120 jours et fait le tour du corps en une minute environ. Tu en as près de 25 000 milliards.',7.5e-6);
(()=>{const hf=q=>(.07+.2*q*q)*Math.sqrt(Math.max(0,1-q**8))+.015,pt=surf=>{const q=surf?Math.sqrt(rnd()):Math.sqrt(rnd())*.97,a=rnd()*TAU,h=hf(q);return[.86*q*Math.cos(a),surf?(rnd()<.5?h:-h):rs()*h*.9,.86*q*Math.sin(a)]};
  for(let i=0;i<1300;i++){const p=pt(true);i%9?put(RBC,p):put(RBC,p,MEMB,.022)}for(let i=0;i<950;i++)put(RBC,pt(false),HEMO,.014);
  for(let i=0;i<220;i++)put(RBC,pt(false),O2,.004);for(let i=0;i<150;i++)put(RBC,pt(false),EAU,.0025)})();
const LYMPHO=cellNode('Lymphocyte','Un globule blanc. Son gros noyau occupe presque toute la cellule. Les lymphocytes B fabriquent les anticorps ; les T reconnaissent et détruisent les cellules infectées.',8e-6);
(()=>{const S=blob(.82,1,.04);fillCell(LYMPHO,S,{nuc:[.04,0,0],nucR:.52,mito:10,mt:4,golgi:0,re:0});for(let i=0;i<130;i++){const p=S.surface();put(LYMPHO,mulS(p,1.04),ANTICORPS,.03,aim(p))}})();
function muscleCell(name,desc,size,nuclei,mito){const n=cellNode(name,desc,size),hl=.9,R=.33,AXX=aimX([1,0,0]);
  const S={inside(){const r=R*Math.sqrt(rnd()),a=rnd()*TAU;return[rs()*hl,r*Math.cos(a),r*Math.sin(a)]},surface(){const a=rnd()*TAU;return[rs()*hl,R*Math.cos(a),R*Math.sin(a)]}};
  fillCell(n,S,{nuc:[-.5,.24,.1],nucR:.085,mito,re:0,golgi:0,mt:0,ribo:60,lyso:3,ves:3});
  for(let i=1;i<nuclei;i++)put(n,[-.5+i*1/(nuclei-1||1),.24*Math.cos(i*2.1),.24*Math.sin(i*2.1)],NOYAU,.085);
  for(let k=-4;k<=4;k++){const z0=k*.21;for(let i=0;i<130;i++){const r=R*.9*Math.sqrt(rnd()),a=rnd()*TAU;put(n,[z0+gs()*.004,r*Math.cos(a),r*Math.sin(a)])}}
  for(let i=0;i<520;i++){const k=(rnd()*8|0)-4,r=R*.88*Math.sqrt(rnd()),a=rnd()*TAU;put(n,[k*.21+.035+rnd()*.03+(rnd()<.5?0:.11),r*Math.cos(a),r*Math.sin(a)],ACTINE,.022,AXX)}
  for(let i=0;i<300;i++){const k=(rnd()*8|0)-4,r=R*.88*Math.sqrt(rnd()),a=rnd()*TAU;put(n,[k*.21+.105,r*Math.cos(a),r*Math.sin(a)],MYOSINE,.05,AXX)}
  return n}
const FIBRE=muscleCell('Fibre musculaire','Une cellule géante, longue de plusieurs centimètres, à plusieurs noyaux. Ses stries sont des rangées d\'actine et de myosine qui coulissent les unes sur les autres pour raccourcir le muscle.',1.5e-4,3,60);
const CARDIO=muscleCell('Cardiomyocyte','La cellule du muscle cardiaque. Elle se contracte sans jamais se reposer, environ 3 milliards de fois dans une vie, et un tiers de son volume est fait de mitochondries.',1e-4,1,110);
const HEPATO=cellNode('Hépatocyte','L\'ouvrière du foie. Elle stocke le sucre, fabrique la bile et les protéines du sang, et neutralise l\'alcool, les médicaments et les toxines.',2.5e-5);
(()=>{const S=blob(.85,1,.05),free=fillCell(HEPATO,S,{mito:48,ribo:180});for(let i=0;i<160;i++)put(HEPATO,free(.01),GLUCOSE,.0035);for(let i=0;i<60;i++)put(HEPATO,free(.01),ENZYME,.008)})();
const KERATINO=cellNode('Kératinocyte','La cellule de l\'épiderme. Née en profondeur, elle monte vers la surface en se remplissant de kératine, s\'aplatit, meurt et forme la couche protectrice de la peau.',2e-5);
(()=>{const S=blob(.86,.6,.05),free=fillCell(KERATINO,S,{mito:14});for(let i=0;i<220;i++)put(KERATINO,free(.03),KERATINE,.035)})();
const PNEUMO=cellNode('Pneumocyte','Une cellule très plate qui tapisse l\'alvéole. Elle est si mince que l\'oxygène la traverse en une fraction de seconde pour rejoindre le sang.',4e-5);
fillCell(PNEUMO,blob(.88,.3,.05),{mito:12,nucR:.2});
const RENALE=cellNode('Cellule du tubule rénal','Elle récupère dans l\'urine en formation l\'eau, le sel et le sucre utiles et les rend au sang. Ce pompage coûte cher : elle est bourrée de mitochondries.',2e-5);
fillCell(RENALE,blob(.84,.95,.05),{mito:70});
const GASTRIQUE=cellNode('Cellule gastrique','Selon son type, elle sécrète l\'acide chlorhydrique, les enzymes digestives ou le mucus qui protège la paroi de l\'estomac contre son propre acide.',2e-5);
(()=>{const S=blob(.84,1,.05),free=fillCell(GASTRIQUE,S,{mito:50,ves:40});for(let i=0;i<120;i++)put(GASTRIQUE,free(.01),ENZYME,.009)})();
const ENTERO=cellNode('Entérocyte','La cellule qui absorbe ta nourriture. Sa face tournée vers l\'intestin porte des milliers de microvillosités, une bordure en brosse qui multiplie sa surface d\'échange.',2.5e-5);
(()=>{const S=tubes(null,[{a:[0,-.85,0],b:[0,.55,0],ra:.38,rb:.38}],0);fillCell(ENTERO,S,{nuc:[0,-.4,0],nucR:.22,mito:36});
  for(let i=0;i<90;i++){const r=.36*Math.sqrt(rnd()),a=rnd()*TAU,b=[r*Math.cos(a),.55,r*Math.sin(a)],t=[b[0],.93,b[2]];line(ENTERO,b,t,14,.006);put(ENTERO,lerp(b,t,.5),MEMB,.02)}
  for(let i=0;i<150;i++){const r=.36*Math.sqrt(rnd()),a=rnd()*TAU;put(ENTERO,[r*Math.cos(a),-.85,r*Math.sin(a)])}})();
const BATONNET=cellNode('Bâtonnet','Le photorécepteur de la vision nocturne. Son segment externe est une pile de disques couverts de rhodopsine, capable de détecter un seul photon. Ta rétine en compte environ 120 millions.',6e-5);
(()=>{const segs=[{a:[0,.25,0],b:[0,.95,0],ra:.13,rb:.12},{a:[0,-.18,0],b:[0,.25,0],ra:.15,rb:.13},{a:[0,-.82,0],b:[0,-.5,0],ra:.04,rb:.05},{a:[0,-.93,0],b:[0,-.82,0],ra:.1,rb:.08}];
  const S=tubes([0,-.36,0,.18],segs,.25);fillCell(BATONNET,S,{nuc:[0,-.36,0],nucR:.13,mito:0,re:0,golgi:0,mt:3,ribo:50,surf:1100});
  for(let i=0;i<40;i++)put(BATONNET,[rs()*.08,-.1+rnd()*.3,rs()*.08],MITO,.045);
  for(let k=0;k<30;k++)for(let i=0;i<26;i++){const r=.115*Math.sqrt(rnd()),a=rnd()*TAU,p=[r*Math.cos(a),.28+k*.022,r*Math.sin(a)];i%4?put(BATONNET,p):put(BATONNET,p,RHODO,.011)}
  for(let i=0;i<24;i++)put(BATONNET,[rs()*.07,-.88+rs()*.04,rs()*.07],VESSYN,.014)})();
const BACTERIE=cellNode('Bactérie intestinale','Une habitante de ton microbiote, bien plus petite que tes cellules et sans noyau : son ADN flotte librement. Tu en héberges environ 38 000 milliards, qui digèrent les fibres et fabriquent des vitamines.',2.5e-6);
(()=>{const S=tubes(null,[{a:[-.45,0,0],b:[.4,0,0],ra:.24,rb:.24}],0);
  for(let i=0;i<1000;i++){const p=S.surface();i%8?put(BACTERIE,p):put(BACTERIE,p,MEMB,.03)}for(const s of[-1,1])for(let i=0;i<120;i++){const d=dir();if(d[0]*s<0)continue;put(BACTERIE,[(s>0?.4:-.45)+d[0]*.24,d[1]*.24,d[2]*.24])}
  const ps=walk(70,.05,.2);ps.forEach((p,i)=>{put(BACTERIE,[p[0]*1.6,p[1],p[2]],ADN,.045);if(i)line(BACTERIE,[ps[i-1][0]*1.6,ps[i-1][1],ps[i-1][2]],[p[0]*1.6,p[1],p[2]],4,.006)});
  for(let i=0;i<220;i++)put(BACTERIE,S.inside(),RIBO,.02);for(let i=0;i<260;i++)put(BACTERIE,S.inside(),PROT,.012);for(let i=0;i<80;i++)put(BACTERIE,S.inside(),ENZYME,.012);
  for(let f=0;f<3;f++)for(let i=0;i<110;i++){const t=rnd();put(BACTERIE,[.62+t*.34,.05*Math.sin(t*14+f*2)+(f-1)*.08,.05*Math.cos(t*14+f*2)])}})();

/* ───────── tissus ───────── */
const tis=(name,desc,size,cat)=>node(name,desc,size,cat||'Tissu');
const CAPILLAIRE=tis('Capillaire sanguin','Le plus fin des vaisseaux : les globules rouges y passent en file indienne, en se déformant. C\'est ici que l\'oxygène et le sucre quittent le sang pour les cellules.',4e-5,'Vaisseau');
(()=>{const cy=x=>.1*Math.sin(2*x);for(let i=0;i<1100;i++){const x=rs()*.95,a=rnd()*TAU;put(CAPILLAIRE,[x,cy(x)+.24*Math.cos(a),.24*Math.sin(a)])}
  [-.76,-.38,0,.38,.76].forEach(x=>put(CAPILLAIRE,[x+gs()*.03,cy(x),0],RBC,.17));
  const inn=()=>{const x=rs()*.95,r=.2*Math.sqrt(rnd()),a=rnd()*TAU;return[x,cy(x)+r*Math.cos(a),r*Math.sin(a)]};
  for(let i=0;i<70;i++)put(CAPILLAIRE,inn(),ANTICORPS,.006);for(let i=0;i<60;i++)put(CAPILLAIRE,inn(),GLUCOSE,.003);for(let i=0;i<120;i++)put(CAPILLAIRE,inn(),EAU,.002);for(let i=0;i<40;i++)put(CAPILLAIRE,inn(),O2,.003);phAxe(CAPILLAIRE,0)})();
const VAISSEAU=tis('Vaisseau sanguin','Une artère ou une veine, vue de l\'intérieur. Mis bout à bout, tes vaisseaux feraient environ 100 000 km. Le sang y charrie globules rouges, globules blancs, sucre, hormones et anticorps.',4e-3,'Vaisseau');
(()=>{for(let i=0;i<2200;i++){const a=rnd()*TAU,R=i%3?.56:.62;put(VAISSEAU,[R*Math.cos(a),rs()*.95,R*Math.sin(a)])}
  const inn=()=>{const r=.52*Math.sqrt(rnd()),a=rnd()*TAU;return[r*Math.cos(a),rs()*.95,r*Math.sin(a)]};
  for(let i=0;i<1500;i++)put(VAISSEAU,inn(),RBC,.028);for(let i=0;i<16;i++)put(VAISSEAU,inn(),LYMPHO,.034);for(let i=0;i<120;i++)put(VAISSEAU,inn(),ANTICORPS,.002);for(let i=0;i<120;i++)put(VAISSEAU,inn(),GLUCOSE,.0012);phAxe(VAISSEAU,1)})();
const SYNAPSE=node('Synapse','Le point de contact entre deux neurones. Le signal électrique arrive par le bouton du haut, qui libère le glutamate de ses vésicules dans une fente de 20 nanomètres. En bas, les canaux du neurone suivant s\'ouvrent et le signal repart. Tu en as environ 100 000 milliards.',1e-6,'Connexion');
(()=>{for(let i=0;i<1100;i++){const d=dir(),p=[.6*d[0],.48+.6*d[1],.6*d[2]];if(p[1]>.06)put(SYNAPSE,p)}
  const disc=R=>{const r=R*Math.sqrt(rnd()),a=rnd()*TAU;return[r*Math.cos(a),r*Math.sin(a)]};
  for(let i=0;i<260;i++){const d=disc(.42);put(SYNAPSE,[d[0],.06,d[1]])}
  for(let i=0;i<34;i++){const p=mulS(inBall(),.42);put(SYNAPSE,[p[0],.5+p[1]*.8,p[2]],VESSYN,.085)}
  put(SYNAPSE,[.15,.85,0],MITO,.15);put(SYNAPSE,[-.2,.8,.1],MITO,.13);
  for(let i=0;i<90;i++){const d=disc(.5);put(SYNAPSE,[d[0],-.08+rnd()*.12,d[1]],GLU,.012)}
  for(let i=0;i<600;i++){const d=disc(.78);put(SYNAPSE,[d[0],-.12,d[1]])}
  for(let i=0;i<32;i++){const d=disc(.5);put(SYNAPSE,[d[0],-.12,d[1]],CANAL,.05,0)}
  for(let i=0;i<500;i++){const d=dir(),p=[.8*d[0],-.72+.8*d[1],.8*d[2]];if(p[1]<-.12)put(SYNAPSE,p)}})();
const EXC=ink('#35e0ff'),INH=ink('#ff4fd8');
function cortexLike(name,desc){const n=tis(name,desc,1.2e-3),ps=[];
  for(let i=0;i<260;i++){const p=mulS(inBall(),.9);ps.push(p);put(n,p,NEURONE,.065)}
  for(let i=0;i<130;i++)put(n,mulS(inBall(),.9),ASTRO,.04);for(let i=0;i<10;i++)put(n,mulS(inBall(),.8),CAPILLAIRE,.16);
  ps.forEach(a=>{for(let k=0;k<2;k++){let b=null,bd=9;for(let t=0;t<7;t++){const q=ps[rnd()*ps.length|0],d=dist(a,q);if(q!==a&&d<bd){bd=d;b=q}}
      const m=add(lerp(a,b,.5),mulS(dir(),bd*.28));INK=rnd()<.22?INH:EXC;
      for(let i=0;i<80;i++){const p=bez(a,m,b,.06+rnd()*.86);put(n,[p[0]+gs()*.002,p[1]+gs()*.002,p[2]+gs()*.002])}INK=0;
      put(n,bez(a,m,b,.93),SYNAPSE,.011)}});
  return n}
const CORTEX=cortexLike('Cortex cérébral','La couche plissée à la surface du cerveau, épaisse de 2 à 4 mm : la matière grise. C\'est là que se traitent la perception, le langage, la mémoire et la décision. Les fils colorés sont les liaisons entre neurones : en cyan les connexions qui excitent, en magenta celles qui freinent. Au bout de chaque fil, une synapse.');
const CORTEXCB=cortexLike('Cortex du cervelet','Le cervelet règle la précision des gestes et l\'équilibre. Il ne pèse qu\'un dixième du cerveau mais contient plus de la moitié de ses neurones. Fils cyan : connexions excitatrices ; magenta : inhibitrices.');
const AXONE=tis('Axone myélinisé','Le câble de sortie d\'un neurone, gainé de myéline, un isolant gras enroulé en couches. Le signal saute d\'un nœud à l\'autre et atteint 100 mètres par seconde.',2e-5,'Prolongement de neurone');
(()=>{for(let i=0;i<500;i++){const a=rnd()*TAU;put(AXONE,[.12*Math.cos(a),rs()*.95,.12*Math.sin(a)])}
  for(const s of[-1,1])for(let i=0;i<900;i++){const a=rnd()*TAU,R=[.22,.27,.32][i%3],p=[R*Math.cos(a),s*(.08+rnd()*.87),R*Math.sin(a)];i%11?put(AXONE,p):put(AXONE,p,MEMB,.05)}
  for(let i=0;i<8;i++)put(AXONE,[rs()*.05,-.85+i*.24,rs()*.05],MICROTUBULE,.1,0);for(let i=0;i<6;i++)put(AXONE,[rs()*.05,rs()*.9,rs()*.05],MITO,.06);
  for(let i=0;i<36;i++){const a=rnd()*TAU;put(AXONE,[.12*Math.cos(a),rs()*.07,.12*Math.sin(a)],CANAL,.018)}phAxe(AXONE,1,-1)})();
const SBLANCHE=tis('Substance blanche','Sous le cortex, des faisceaux de millions d\'axones relient les régions du cerveau entre elles. Leur gaine de myéline, grasse, leur donne cette couleur claire.',1.2e-3);
(()=>{const AXX=RX_Y;for(let f=0;f<60;f++){const y=rs()*.8,z=rs()*.8;if(y*y+z*z>.72)continue;const ph=rnd()*6;
    for(let i=-6;i<=6;i++){const x=i*.14;put(SBLANCHE,[x,y+.03*Math.sin(3*x+ph),z+.03*Math.cos(2*x+ph)],AXONE,.07,AXX)}}
  for(let i=0;i<40;i++)put(SBLANCHE,mulS(inBall(),.85),ASTRO,.04);for(let i=0;i<4;i++)put(SBLANCHE,mulS(inBall(),.7),CAPILLAIRE,.16)})();
const ALVEOLE=tis('Alvéole pulmonaire','Un petit sac d\'air entouré de capillaires. L\'oxygène passe dans le sang, le CO₂ fait le chemin inverse. Tes poumons en comptent environ 480 millions, soit la surface d\'un demi-terrain de tennis.',2.5e-4,'Unité du poumon');
(()=>{for(let i=0;i<240;i++){const d=dir();put(ALVEOLE,mulS(d,.78),PNEUMO,.075,aim(d))}for(let i=0;i<34;i++){const d=dir();put(ALVEOLE,mulS(d,.86),CAPILLAIRE,.19,aimX(perp(d)))}
  for(let i=0;i<500;i++)put(ALVEOLE,mulS(dir(),.78));for(let i=0;i<160;i++)put(ALVEOLE,mulS(inBall(),.7),O2,.004);for(let i=0;i<60;i++)put(ALVEOLE,mulS(inBall(),.7),CO2,.004)})();
const LOBULE=tis('Lobule hépatique','L\'unité du foie : des travées d\'hépatocytes disposées en rayons autour d\'une veine centrale. Le sang venu de l\'intestin les longe et s\'y fait filtrer.',1.5e-3,'Unité du foie');
(()=>{for(let c=0;c<26;c++){const a=c*TAU/26;for(let k=0;k<8;k++)for(let l=-2;l<=2;l++){const r=.16+k*.095;put(LOBULE,[r*Math.cos(a),l*.2+gs()*.02,r*Math.sin(a)],HEPATO,.046)}}
  for(let i=0;i<70;i++){const a=(rnd()*26|0)*TAU/26+TAU/52,r=.2+rnd()*.6;put(LOBULE,[r*Math.cos(a),rs()*.45,r*Math.sin(a)],CAPILLAIRE,.085,aimX([Math.cos(a),0,Math.sin(a)]))}
  for(let i=0;i<300;i++){const a=rnd()*TAU;put(LOBULE,[.09*Math.cos(a),rs()*.55,.09*Math.sin(a)])}
  for(let i=0;i<6;i++){const a=i*TAU/6;put(LOBULE,[.92*Math.cos(a),0,.92*Math.sin(a)],VAISSEAU,.06,0)}})();
const NEPHRON=tis('Néphron','Le filtre du rein. Le sang est filtré dans un peloton de capillaires (le glomérule), puis un long tubule en épingle récupère l\'eau et les sels utiles. Chaque rein en contient environ un million.',3e-3,'Unité du rein');
(()=>{const g=[-.45,.6,0];for(let i=0;i<26;i++)put(NEPHRON,add(g,mulS(inBall(),.17)),CAPILLAIRE,.07);for(let i=0;i<500;i++)put(NEPHRON,add(g,mulS(dir(),.24)));
  const pts=[];for(let i=0;i<=40;i++){const t=i/40;pts.push([-.2+.3*t+.12*Math.sin(t*22),.6-.25*t+.12*Math.cos(t*17),.1*Math.sin(t*13)])}
  for(let i=1;i<=20;i++)pts.push([.1,.35-i*.06,0]);for(let i=0;i<=20;i++)pts.push([.22,-.85+i*.06,0]);
  for(let i=0;i<=30;i++){const t=i/30;pts.push([.3+.2*t+.1*Math.sin(t*20),.38+.2*t+.1*Math.cos(t*15),.08*Math.sin(t*11)])}
  for(let i=0;i<=24;i++)pts.push([.72,.6-i*.065,0]);
  for(let i=1;i<pts.length;i++){const a=pts[i-1],b=pts[i],ax=norm(sub(b,a));for(let k=0;k<5;k++)put(NEPHRON,add(b,mulS(perp(ax),.032)),RENALE,.022);line(NEPHRON,a,b,3,.004)}
  for(let i=0;i<8;i++)put(NEPHRON,[.16,-.7+i*.13,.06],CAPILLAIRE,.07,RX_Y)})();
const FAISCEAU=tis('Faisceau musculaire','Un paquet de fibres musculaires parallèles, enveloppé de tissu conjonctif. Quand le nerf commande, toutes les fibres se raccourcissent ensemble. Les muscles représentent environ 40 % de ton poids.',1.2e-3,'Muscle');
(()=>{for(let i=-4;i<=4;i++)for(let j=-4;j<=4;j++){const y=i*.2+(j%2?.1:0),z=j*.175;if(y*y+z*z>.62)continue;[-.56,0,.56].forEach(x=>put(FAISCEAU,[x,y,z],FIBRE,.3,0))}
  for(let i=0;i<40;i++){const a=rnd()*TAU,r=.75*Math.sqrt(rnd());put(FAISCEAU,[rs()*.7,r*Math.cos(a)+.1,r*Math.sin(a)],CAPILLAIRE,.08)}
  for(let i=0;i<800;i++){const a=rnd()*TAU;put(FAISCEAU,[rs()*.85,.86*Math.cos(a),.86*Math.sin(a)])}})();
const TCARD=tis('Tissu cardiaque','Des cardiomyocytes soudés bout à bout en un réseau ramifié. Le signal électrique passe de cellule en cellule, et tout le cœur se contracte d\'un seul coup, environ 100 000 fois par jour.',5e-4,'Muscle du cœur');
(()=>{for(let i=-3;i<=3;i++)for(let j=-3;j<=3;j++)for(let k=-2;k<=2;k++){const p=[k*.34+(i%2?.17:0),i*.13,j*.13];if(len(p)>.9)continue;put(TCARD,p,CARDIO,.185,0)}
  for(let i=0;i<30;i++)put(TCARD,mulS(inBall(),.85),CAPILLAIRE,.1);for(let i=0;i<500;i++)put(TCARD,mulS(dir(),.92))})();
const OSTEON=tis('Ostéon','L\'unité de l\'os compact : des lamelles concentriques autour d\'un canal où passent vaisseaux et nerfs. L\'os est vivant : ton squelette se renouvelle entièrement en une dizaine d\'années.',2.5e-4,'Os');
(()=>{put(OSTEON,[0,0,0],CAPILLAIRE,.13,RX_Y);put(OSTEON,[0,.5,0],CAPILLAIRE,.13,RX_Y);put(OSTEON,[0,-.5,0],CAPILLAIRE,.13,RX_Y);
  [.25,.43,.61,.79].forEach((R,ri)=>{for(let i=0;i<650;i++){const a=rnd()*TAU;put(OSTEON,[R*Math.cos(a),rs()*.8,R*Math.sin(a)])}
    for(let i=0;i<8+ri*6;i++){const a=rnd()*TAU;put(OSTEON,[(R+.09)*Math.cos(a),rs()*.75,(R+.09)*Math.sin(a)],OSTEO,.05)}});
  for(let i=0;i<280;i++){const a=rnd()*TAU,r=.2+rnd()*.65;put(OSTEON,[r*Math.cos(a),rs()*.8,r*Math.sin(a)],COLLAGENE,.012,RX_Y)}
  for(let i=0;i<380;i++){const a=rnd()*TAU,r=.2+rnd()*.65;put(OSTEON,[r*Math.cos(a),rs()*.8,r*Math.sin(a)],APATITE,.005)}})();
const EPIDERME=tis('Peau','En haut, l\'épiderme : des kératinocytes qui montent et s\'aplatissent en une couche morte et étanche. En dessous, le derme, riche en collagène et en capillaires. La peau est ton plus grand organe : près de 2 m².',3e-4,'Tissu');
(()=>{const disc=()=>{const r=.85*Math.sqrt(rnd()),a=rnd()*TAU;return[r*Math.cos(a),r*Math.sin(a)]};
  for(let L=0;L<7;L++)for(let i=0;i<70;i++){const d=disc(),b=.06*Math.sin(5*d[0])*Math.cos(4*d[1]);put(EPIDERME,[d[0],-.1+L*.105+b*(1-L/7),d[1]],KERATINO,.058,L<3?undefined:0)}
  for(let i=0;i<1300;i++){const d=disc();put(EPIDERME,[d[0],.66+rnd()*.1,d[1]])}
  for(let i=0;i<300;i++){const d=disc();put(EPIDERME,[d[0],-.25-rnd()*.55,d[1]],COLLAGENE,.03,aimX([rs(),rs()*.3,rs()]))}
  for(let i=0;i<7;i++){const d=disc();put(EPIDERME,[d[0]*.8,-.3-rnd()*.4,d[1]*.8],CAPILLAIRE,.15)}})();
const VILLOSITE=tis('Villosité intestinale','Un doigt minuscule de la paroi de l\'intestin. Couvert d\'entérocytes, il absorbe les nutriments et les passe au capillaire qui court en son centre. Autour flottent les bactéries du microbiote.',1e-3,'Unité de l\'intestin');
(()=>{for(let i=0;i<420;i++){let p,nrm;if(rnd()<.8){const a=rnd()*TAU;nrm=[Math.cos(a),0,Math.sin(a)];p=[.3*nrm[0],-.85+rnd()*1.3,.3*nrm[2]]}else{const d=dir();if(d[1]<0)d[1]=-d[1];nrm=d;p=[.3*d[0],.45+.3*d[1],.3*d[2]]}
    put(VILLOSITE,p,ENTERO,.06,aim(nrm))}
  for(let i=0;i<7;i++){const a=rnd()*TAU,r=.14*rnd();put(VILLOSITE,[r*Math.cos(a),-.6+i*.18,r*Math.sin(a)],CAPILLAIRE,.16,RX_Y)}
  for(let i=0;i<70;i++){const a=rnd()*TAU,r=.5+rnd()*.4;put(VILLOSITE,[r*Math.cos(a),rs()*.85,r*Math.sin(a)],BACTERIE,.03)}
  for(let i=0;i<400;i++){const a=rnd()*TAU,r=.42+rnd()*.5;put(VILLOSITE,[r*Math.cos(a),rs()*.9,r*Math.sin(a)])}})();
const RETINE=tis('Rétine','L\'écran au fond de l\'œil, épais d\'un quart de millimètre. Les photorécepteurs captent la lumière, puis deux couches de neurones trient le signal avant de l\'envoyer au cerveau par le nerf optique.',3e-4);
(()=>{for(let i=-7;i<=7;i++)for(let j=-7;j<=7;j++){const x=i*.115+(j%2?.057:0),z=j*.1;if(x*x+z*z>.72)continue;put(RETINE,[x,-.42,z],BATONNET,.19,0)}
  const disc=()=>{const r=.85*Math.sqrt(rnd()),a=rnd()*TAU;return[r*Math.cos(a),r*Math.sin(a)]};
  for(let i=0;i<110;i++){const d=disc();put(RETINE,[d[0],.02+rnd()*.26,d[1]],NEURONE,.09)}for(let i=0;i<55;i++){const d=disc();put(RETINE,[d[0],.5+rnd()*.2,d[1]],NEURONE,.1)}
  for(let i=0;i<900;i++){const d=disc();put(RETINE,[d[0],-.64+gs()*.012,d[1]])}for(let i=0;i<5;i++){const d=disc();put(RETINE,[d[0]*.8,.8,d[1]*.8],CAPILLAIRE,.15)}})();
const GLANDE=tis('Glande gastrique','Un puits creusé dans la paroi de l\'estomac. Ses cellules y déversent acide et enzymes : environ deux litres de suc gastrique par jour.',4e-4,'Unité de l\'estomac');
(()=>{for(let i=0;i<300;i++){const y=-.85+rnd()*1.7,R=.26+(y>.4?(y-.4)*.9:0),a=rnd()*TAU;put(GLANDE,[R*Math.cos(a),y,R*Math.sin(a)],GASTRIQUE,.072,aim([Math.cos(a),0,Math.sin(a)]))}
  for(let i=0;i<500;i++){const r=.18*Math.sqrt(rnd()),a=rnd()*TAU;put(GLANDE,[r*Math.cos(a),rs()*.85,r*Math.sin(a)])}
  for(let i=0;i<60;i++){const r=.16*Math.sqrt(rnd()),a=rnd()*TAU;put(GLANDE,[r*Math.cos(a),rs()*.85,r*Math.sin(a)],ENZYME,.004)}
  for(let i=0;i<7;i++){const a=rnd()*TAU;put(GLANDE,[.6*Math.cos(a),rs()*.6,.6*Math.sin(a)],CAPILLAIRE,.15)}})();

/* ───────── organes ───────── */
const org=(name,desc,size)=>node(name,desc,size,'Organe');
const CERVEAU=org('Cerveau','1,4 kg, 86 milliards de neurones, 20 % de l\'énergie du corps. En surface, le cortex plissé ; dessous, la substance blanche qui câble le tout ; à l\'arrière, le cervelet. Les faisceaux colorés sont les grandes liaisons : rouge entre les deux hémisphères, vert d\'avant en arrière, bleu vers la moelle.',.17);
(()=>{let n=0;while(n<3600){const d=dir(),w=Math.sin(13*d[0]+3*Math.sin(9*d[1]))*Math.sin(11*d[2]+4*Math.sin(8*d[0]+2));if(Math.abs(w)<.2)continue;
    const s=rnd()<.5?-1:1,k=1+.035*w;put(CERVEAU,[s*(.03+Math.abs(d[0])*.52*k),.14+d[1]*.45*k,d[2]*.8*k],CORTEX,.015);n++}
  for(let i=0;i<900;i++){const d=inBall(),s=d[0]<0?-1:1;put(CERVEAU,[s*(.03+Math.abs(d[0])*.44),.14+d[1]*.37,d[2]*.68],SBLANCHE,.017)}
  n=0;while(n<750){const d=dir();if(Math.sin(34*d[1])<-.1)continue;put(CERVEAU,[d[0]*.42,-.34+d[1]*.2,-.5+d[2]*.27],CORTEXCB,.015);n++}
  for(let i=0;i<260;i++){const t=rnd(),a=rnd()*TAU,r=.085*Math.sqrt(rnd());put(CERVEAU,[r*Math.cos(a),-.15-t*.75,-.18-t*.1+r*Math.sin(a)],SBLANCHE,.017)}
  // grands faisceaux de liaison, colorés selon leur direction comme en imagerie de diffusion
  const RED=ink('#ff3d55'),GRN=ink('#3dff7a'),BLU=ink('#4a8dff');
  const tract=(a,m,b,col)=>{INK=col;for(let i=0;i<90;i++){const p=bez(a,m,b,rnd());put(CERVEAU,[p[0]+gs()*.005,p[1]+gs()*.005,p[2]+gs()*.005])}INK=0};
  for(let i=0;i<80;i++){const z=rs()*.6,x=.14+rnd()*.34;tract([-x,.2+rnd()*.32,z],[0,.1+rnd()*.1,z*.8],[x,.2+rnd()*.32,z+rs()*.1],RED)}
  for(let i=0;i<80;i++){const sd=i%2?1:-1,x=sd*(.1+rnd()*.3),y=.02+rnd()*.36;tract([x,y,-.62+rnd()*.2],[x+rs()*.06,y+.14,rs()*.15],[x,y+rs()*.1,.42+rnd()*.28],GRN)}
  for(let i=0;i<70;i++){const sd=i%2?1:-1;tract([sd*(.1+rnd()*.34),.32+rnd()*.22,rs()*.5],[sd*.1,-.02,-.1],[sd*.04*rnd(),-.3-rnd()*.55,-.2-rnd()*.08],BLU)}})();
const COEUR=org('Cœur','Une pompe musculaire de la taille du poing. Quatre cavités, 5 litres de sang par minute au repos, environ 100 000 battements par jour sans une seule pause.',.13);
(()=>{let n=0;while(n<2500){const x=rs()*1.2,y=-1.2+rnd()*2.5,z=rs()*.75,f=(x*x+2.25*z*z+y*y-1)**3-x*x*y*y*y-.1125*z*z*y*y*y;if(f>0||(f<-.35&&rnd()<.75))continue;
    const p=[x*.6+y*.1,y*.6-x*.1-.08,z*.6];f>-.05&&rnd()<.06?put(COEUR,p,VAISSEAU,.014):put(COEUR,p,TCARD,.017);n++}
  for(let i=0;i<220;i++){const t=rnd()*2.6,a=rnd()*TAU,c=[.05-.3*(1-Math.cos(t))*.9,.5+.3*Math.sin(t),0];put(COEUR,[c[0]+.09*Math.cos(a),c[1]+.02*gs(),.09*Math.sin(a)],VAISSEAU,.02)}})();
const POUMON=org('Poumon','Un arbre de bronches qui se divise 23 fois, jusqu\'aux alvéoles où l\'air rencontre le sang. Au repos tu respires environ 12 fois par minute, soit plus de 8 000 litres d\'air par jour.',.26);
(()=>{const g=(p,d,l,depth,s)=>{const q=add(p,mulS(d,l));if(Math.abs(q[0])>.45||Math.abs(q[1])>.85||Math.abs(q[2])>.5)return;line(POUMON,p,q,l*90+6,.004,s,s+l);
    if(depth>0)for(let i=0;i<2;i++)g(q,norm(add(d,mulS(dir(),.8))),l*.78,depth-1,s+l)};g([0,.85,0],[0,-1,0],.3,7,1.4);
  let n=0;while(n<3000){const d=inBall(),y=d[1]*.9,k=.38+.14*(.9-y)/1.8;put(POUMON,[d[0]*k*1.25,y,d[2]*(.45+.15*(.9-y)/1.8)],ALVEOLE,.019);n++}})();
const FOIE=org('Foie','L\'usine chimique du corps, 1,5 kg. Il stocke le sucre, fabrique la bile, épure le sang et accomplit plus de 500 fonctions. Il peut se régénérer même amputé des deux tiers.',.2);
(()=>{for(let i=0;i<3000;i++){const d=inBall(),k=1-.55*(d[0]+1)/2;put(FOIE,[d[0]*.9,d[1]*.52*k+.1*(1-k),d[2]*.5*k],LOBULE,.017)}
  for(let i=0;i<60;i++){const t=rnd();put(FOIE,[-.3+t*.5+gs()*.03,-.2+t*.25,gs()*.04],VAISSEAU,.022)}})();
function tube(n,pts,rad,count,fn,ph0){const L=[0];for(let i=1;i<pts.length;i++)L.push(L[i-1]+dist(pts[i-1],pts[i]));const T=L[L.length-1];
  for(let c=0;c<count;c++){const u=rnd()*T;let i=1;while(i<pts.length-1&&L[i]<u)i++;const f=(u-L[i-1])/(L[i]-L[i-1]||1),ax=norm(sub(pts[i],pts[i-1]));
    const r=typeof rad==='number'?rad:rad[i-1]+(rad[i]-rad[i-1])*f,nr=perp(ax);if(ph0!==undefined)PH=ph0+u;fn(add(lerp(pts[i-1],pts[i],f),mulS(nr,r)),nr,lerp(pts[i-1],pts[i],f),r)}
  PH=0;return T}
const ESTOMAC=org('Estomac','Une poche musclée qui brasse le repas dans un acide capable de dissoudre du métal (pH 1 à 2). Sa paroi se protège par une couche de mucus renouvelée en continu.',.22);
(()=>{const Q=[[.2,.8,0,.03],[.24,.7,0,.2],[.26,.48,0,.31],[.22,.15,0,.3],[.1,-.2,0,.26],[-.15,-.42,0,.2],[-.42,-.4,0,.13],[-.62,-.28,0,.085]],P=[],R=[];
  for(let i=0;i<Q.length-1;i++)for(let j=0;j<6;j++){const t=j/6,a=Q[Math.max(0,i-1)],b=Q[i],c=Q[i+1],d=Q[Math.min(Q.length-1,i+2)],v=b.map((_,q)=>.5*(2*b[q]+(c[q]-a[q])*t+(2*a[q]-5*b[q]+4*c[q]-d[q])*t*t+(3*b[q]-a[q]-3*c[q]+d[q])*t*t*t));P.push(v.slice(0,3));R.push(v[3])}
  P.push(Q[Q.length-1].slice(0,3));R.push(.085);
  tube(ESTOMAC,P,R,2600,(p,nr)=>rnd()<.7?put(ESTOMAC,p,GLANDE,.017,aim(mulS(nr,-1))):put(ESTOMAC,p),3.2);
  // cardia : l'arrivée de l'œsophage, en haut, côté médian
  tube(ESTOMAC,[[-.12,.95,0],[-.08,.72,0],[.02,.52,0]],[.07,.075,.09],260,(p,nr)=>rnd()<.3?put(ESTOMAC,p,GLANDE,.017,aim(mulS(nr,-1))):put(ESTOMAC,p),2.7)})();
const REIN=org('Rein','Deux filtres en forme de haricot. Ensemble ils filtrent tout ton sang environ 40 fois par jour, soit 180 litres, pour ne rejeter qu\'un litre et demi d\'urine.',.11);
(()=>{let n=0;while(n<2500){const d=inBall(),l=len(d),p=[d[0]*.5,d[1]*.85,d[2]*.4];if(dist(p,[-.62,0,0])<.42)continue;
    if(l>.6){put(REIN,p,NEPHRON,.019);n++}else if(rnd()<.35){put(REIN,p);n++}}
  for(let i=0;i<300;i++){const t=rnd(),a=rnd()*TAU;put(REIN,[-.3-.1*t+.05*Math.cos(a),-t*.95,.05*Math.sin(a)])}})();
const INTESTINS=org('Intestins','Six à sept mètres de tube repliés dans le ventre. L\'intestin grêle absorbe les nutriments sur une surface d\'environ 30 m² ; le côlon, autour, récupère l\'eau et abrite le microbiote.',.3);
(()=>{const P=[];for(let i=0;i<=260;i++){const t=i/260;P.push([.5*Math.sin(t*34)*(1-.25*t),.5-t*1.05,.14*Math.cos(t*21)])}
  const TG=tube(INTESTINS,P,.075,3400,(p,nr)=>rnd()<.6?put(INTESTINS,p,VILLOSITE,.014,aim(mulS(nr,-1))):put(INTESTINS,p),4);   // phase : distance depuis la bouche
  const C=[];[[-.74,-.7],[-.76,.1],[-.7,.72],[0,.8],[.7,.72],[.76,.1],[.72,-.6],[.3,-.9]].forEach((q,i,a)=>{if(i)for(let k=1;k<=10;k++)C.push([a[i-1][0]+(q[0]-a[i-1][0])*k/10,a[i-1][1]+(q[1]-a[i-1][1])*k/10,0]);else C.push([q[0],q[1],0])});
  tube(INTESTINS,C,.12,1500,(p,nr,c)=>{const b=1+.12*Math.sin((c[0]+c[1])*26);rnd()<.2?put(INTESTINS,add(c,mulS(nr,.1*rnd())),BACTERIE,.005):put(INTESTINS,add(c,mulS(nr,.12*b)))},4+TG)})();
const OEIL=org('Œil','Une chambre noire de 24 mm. La cornée et le cristallin font la mise au point, l\'iris règle la lumière, et la rétine, au fond, transforme l\'image en signaux nerveux.',.024);
(()=>{for(let i=0;i<1100;i++){const d=dir();if(d[2]>.75&&rnd()<.8)continue;put(OEIL,mulS(d,.85))}
  for(let i=0;i<300;i++){const d=dir();if(d[2]<.55)continue;put(OEIL,[d[0]*.5,d[1]*.5,.62+d[2]*.34])}
  for(let i=0;i<800;i++){const a=(rnd()*90|0)*TAU/90+gs()*.008,r=.15+rnd()*.25;put(OEIL,[r*Math.cos(a),r*Math.sin(a),.7])}
  for(let i=0;i<260;i++){const d=dir();put(OEIL,[d[0]*.3,d[1]*.3,.55+d[2]*.11])}
  let n=0;while(n<1500){const d=dir();if(d[2]>.25)continue;put(OEIL,mulS(d,.8),RETINE,.03,aim(mulS(d,-1)));n++}
  for(let i=0;i<260;i++){const t=rnd(),a=rnd()*TAU;put(OEIL,[.12+.08*Math.cos(a),.08*Math.sin(a),-.82-t*.17])}})();

/* ───────── anatomie macroscopique : outils ───────── */
// Repère du corps : y de −0,98 (plante des pieds) à +0,96 (sommet du crâne), +z vers l'avant, +x = côté gauche de la personne. 1 unité ≈ 0,9 m.
// Systèmes : 0 peau · 1 squelette · 2 muscles · 3 cœur et artères · 4 veines · 5 système nerveux · 6 respiratoire · 7 digestif · 8 urinaire
//            9 endocrinien · 10 lymphatique et immunitaire · 11 reproducteur · 12 organes des sens
// spline scalaire passant par des clés [x, valeur] (x croissant)
const spline=k=>x=>{let i=1;while(i<k.length-1&&x>k[i][0])i++;const a=k[Math.max(0,i-2)],b=k[i-1],c=k[i],d=k[Math.min(k.length-1,i+1)],w=c[0]-b[0],t=Math.max(0,Math.min(1,(x-b[0])/w));
  const m1=(c[1]-a[1])/(c[0]-a[0])*w,m2=(d[1]-b[1])/(d[0]-b[0])*w,t2=t*t,t3=t2*t;return(2*t3-3*t2+1)*b[1]+(t3-2*t2+t)*m1+(3*t2-2*t3)*c[1]+(t3-t2)*m2};
// courbe lisse (Catmull-Rom) passant par les points donnés, k échantillons par intervalle ; toutes les composantes sont interpolées (la 4e peut porter un rayon)
const lisse=(pts,k=4)=>{const o=[],g=i=>pts[Math.max(0,Math.min(pts.length-1,i))];
  for(let i=0;i<pts.length-1;i++){const a=g(i-1),b=g(i),c=g(i+1),d=g(i+2);
    for(let j=0;j<k;j++){const t=j/k,t2=t*t,t3=t2*t;o.push(b.map((_,q)=>.5*(2*b[q]+(c[q]-a[q])*t+(2*a[q]-5*b[q]+4*c[q]-d[q])*t2+(3*b[q]-a[q]-3*c[q]+d[q])*t3)))}}
  o.push(pts[pts.length-1].slice());return o};
const longueur=pts=>{let L=0;for(let i=1;i<pts.length;i++)L+=dist(pts[i-1],pts[i]);return L};
const auLong=(pts,u)=>{let s=0;for(let i=1;i<pts.length;i++){const d=dist(pts[i-1],pts[i]);if(u<=s+d||i===pts.length-1)return{p:lerp(pts[i-1],pts[i],Math.max(0,Math.min(1,(u-s)/(d||1)))),t:norm(sub(pts[i],pts[i-1]))};s+=d}};
// point d'une courbe descendante à la hauteur y, et distance parcourue jusque-là
const surY=(pts,y)=>{let s=0;for(let i=1;i<pts.length;i++){const a=pts[i-1],b=pts[i];if((a[1]-y)*(b[1]-y)<=0&&a[1]!==b[1]){const f=(a[1]-y)/(a[1]-b[1]);return{p:lerp(a,b,f),s:s+dist(a,b)*f}}s+=dist(a,b)}return{p:pts[pts.length-1],s}};
// rotations orientées, mises en commun par direction arrondie (x vrai : c'est l'axe x de l'enfant qui vise d, sinon son axe y)
const ROTQ=new Map();
const vers=(d,x)=>{d=norm(d);const k=(x?'x':'y')+Math.round(d[0]*7)+','+Math.round(d[1]*7)+','+Math.round(d[2]*7);if(!ROTQ.has(k))ROTQ.set(k,x?aimX(d):aim(d));return ROTQ.get(k)};
const repere=(y,xh)=>{y=norm(y);const x=norm(sub(xh,mulS(y,dot(xh,y))));return rotCols(x,y,cross(x,y))};      // axe y imposé, axe x au plus près de xh
const RY180=rotCols([-1,0,0],[0,1,0],[0,0,-1]),RZ180=rotCols([-1,0,0],[0,-1,0],[0,0,1]);
const surEll=(c,r)=>{const d=dir();return[c[0]+d[0]*r[0],c[1]+d[1]*r[1],c[2]+d[2]*r[2]]};
const dansEll=(c,r)=>{const d=inBall();return[c[0]+d[0]*r[0],c[1]+d[1]*r[1],c[2]+d[2]*r[2]]};
const loc=(c,r)=>p=>[(p[0]-c[0])/r,(p[1]-c[1])/r,(p[2]-c[2])/r].concat(p.length>3?[p[3]/r]:[]);
// sème nb points le long d'une courbe, à la distance r0→r1 de l'axe (o.plein : dans tout le volume). o.ph : phase de départ (elle croît avec la distance
// parcourue) ; o.axe ('x' ou 'y') : axe de l'enfant aligné sur la courbe ; o.W : déformation appliquée au point. Renvoie la phase d'arrivée.
function semer(n,pts,r0,r1,nb,c,rc,o={}){const L=[0];for(let i=1;i<pts.length;i++)L.push(L[i-1]+dist(pts[i-1],pts[i]));
  const T=L[L.length-1]||1e-6;let i=1;
  for(let k=0;k<nb;k++){const u=(k+rnd())/nb*T;while(i<pts.length-1&&L[i]<u)i++;
    const a=pts[i-1],b=pts[i],f=(u-L[i-1])/(L[i]-L[i-1]||1),ax=norm(sub(b,a)),r=(r0+(r1-r0)*u/T)*(o.plein?Math.sqrt(rnd()):1);
    if(o.ph!==undefined)PH=o.ph+u;
    const q=add(lerp(a,b,f),mulS(perp(ax),r));put(n,o.W?o.W(q):q,c,rc,c&&o.axe?vers(ax,o.axe==='x'):undefined)}
  PH=0;return(o.ph||0)+T}
// encres des structures (points sans enfant : cartilage, tendons, parois…) et teintes imposées aux points-enfants du corps
const E_PEAU=ink('#5c483c'),E_OS=ink('#cfc6a6'),E_MUSC=ink('#a8423a'),E_ART=ink('#ff3830'),E_VEIN=ink('#3f6dff'),E_NERF=ink('#fff09a'),E_LYMPH=ink('#5fd68a'),
  E_CART=ink('#9fc4cc'),E_DENT=ink('#b8b8b0'),E_TEND=ink('#b8ad90'),E_DIG=ink('#b88a30'),E_AIR=ink('#5f9fc8'),E_URI=ink('#9a70d0'),E_GRIS=ink('#c88aa0'),
  E_REPRO=ink('#c870a8'),E_PAROI=ink('#a83038'),E_PAROIV=ink('#3048a8'),E_JAUNE=ink('#c8a840'),E_SOUFRE=ink('#ffe14d'),E_PALE=ink('#8a8a90');

/* ───────── géométrie partagée entre le corps et les nœuds d'organes (repère du corps, côté gauche) ───────── */
// colonne : profondeur z du centre des corps vertébraux selon la hauteur (lordose cervicale, cyphose thoracique, lordose lombaire, sacrum)
const zR=spline([[-.01,-.078],[.03,-.088],[.085,-.07],[.136,-.042],[.2,-.024],[.26,-.022],[.336,-.045],[.45,-.068],[.56,-.06],[.646,-.034],[.72,-.014],[.785,-.022]]);
const VERT=[];(()=>{let y=.785;const serie=(nb,h,type,r0,r1)=>{for(let i=0;i<nb;i++){VERT.push({y:y-h/2,h,type,rb:r0+(r1-r0)*i/(nb-1)});y-=h}};
  serie(7,.0199,'C',.009,.0105);serie(12,.0258,'T',.011,.017);serie(5,.04,'L',.019,.023)})();       // C1…C7, T1…T12, L1…L5
const canalZ=y=>zR(y)-(y>.646?.0165:y>.336?.02:.026);           // axe du canal vertébral
// une vertèbre : corps, arc, épineuse, transverses, articulaires. E(point, 0 corps | 1 arc et apophyses)
function vertebre(E,v,q){const y=v.y,z=zR(y),rb=v.rb,hb=v.h*.39,T=v.type,rc=T==='T'?.0075:T==='C'?.008:.009,zc=z-rb*.8-rc,N=k=>Math.max(1,Math.round(k*q));
  for(let i=0;i<N(15);i++){const a=rnd()*TAU,t=rs(),r=rb*(.9+.1*t*t)*(Math.sin(a)<-.5?.92:1);E([r*Math.cos(a),y+t*hb,z+r*.8*Math.sin(a)],0)}
  for(let i=0;i<N(5);i++){const a=rnd()*TAU,r=rb*Math.sqrt(rnd());E([r*Math.cos(a),y+(i%2?hb:-hb),z+r*.8*Math.sin(a)],0)}
  for(let i=0;i<N(9);i++){const a=rs()*2.1;E([rc*1.3*Math.sin(a),y+rs()*hb*.7,zc-rc*1.05*Math.cos(a)],1)}
  const ep=T==='C'?[0,-.004,-.016]:T==='T'?[0,-.026,-.024]:[0,-.004,-.036],tr=T==='C'?[.024,0,.006]:T==='T'?[.034,.004,-.014]:[.046,0,-.002],j=rc*.3;
  for(let i=0;i<N(5);i++){const t=rnd();E([gs()*j*.5,y+ep[1]*t+rs()*hb*(T==='L'?.7:.25),zc-rc+ep[2]*t],1)}
  for(const s of[-1,1]){for(let i=0;i<N(3);i++){const t=rnd();E([s*(rc*1.2+(tr[0]-rc*1.2)*t),y+tr[1]*t+gs()*j,zc+tr[2]*t+gs()*j],1)}
    for(const u of[-1,1])for(let i=0;i<N(.8);i++)E([s*rc*1.45+gs()*.002,y+u*hb*1.15,zc-rc*.5+gs()*.002],1)}}
// fémur gauche : tête, col, grand et petit trochanters, diaphyse oblique, condyles. E(point, axe local de l'os)
const FEM={tete:[.095,.035,.003],diaph:[[.158,-.005,.003],[.14,-.12,.003],[.115,-.27,.003],[.094,-.385,.003]],c:[.125,-.198,.003],r:.265};
function femurG(E,q){const N=k=>Math.round(k*q),H=FEM.tete,ax=norm(sub(FEM.diaph[3],FEM.diaph[0])),col=norm([.053,-.023,0]);
  for(let i=0;i<N(60);i++)E(add(H,mulS(dir(),.026)),col);
  const tub=(pts,r0,r1,nb,a)=>{const P=lisse(pts,4),T=longueur(P);for(let i=0;i<nb;i++){const u=(i+rnd())/nb*T,o=auLong(P,u);E(add(o.p,mulS(perp(o.t),r0+(r1-r0)*u/T)),a||o.t)}};
  tub([H,[.148,.012,.003]],.016,.019,N(28),col);
  for(let i=0;i<N(45);i++)E(surEll([.168,.03,.003],[.02,.03,.022]),ax);
  for(let i=0;i<N(12);i++)E(surEll([.128,-.025,-.008],[.012,.014,.012]),ax);
  tub(FEM.diaph,.0165,.0165,N(200));tub([[.094,-.385,.003],[.087,-.42,.003]],.0175,.034,N(34),ax);
  for(const x of[.063,.107])for(let i=0;i<N(48);i++)E(surEll([x,-.432,.003],[.021,.024,.032]),ax)}
// trajets des grands conduits du tronc
const CH={
  aoAsc:[[.002,.512,.038],[-.012,.535,.042],[-.012,.556,.036],[-.002,.571,.02],[.012,.572,-.002],[.022,.56,-.025],[.024,.535,-.04]],      // racine, aorte ascendante, crosse
  aoDesc:[[.024,.535,-.04],[.022,.47,-.042],[.016,.41,-.034],[.009,.35,-.018],[.007,.29,.002],[.005,.2,.012]],                             // aorte descendante, jusqu'à la bifurcation (L4)
  tronc:[[-.006,.571,.024],[-.02,.59,.015],[-.028,.603,.01]],carG:[[.006,.573,.006],[.022,.59,.01],[.03,.61,.012]],scG:[[.016,.568,-.012],[.03,.59,-.006],[.04,.612,-.003]],
  vcs:[[-.02,.513,.035],[-.026,.545,.03],[-.026,.578,.022]],                                                                               // veine cave supérieure (de l'oreillette vers le haut)
  vci:[[-.012,.468,.035],[-.02,.43,.02],[-.024,.4,.008],[-.024,.35,0],[-.02,.29,.006],[-.012,.2,.008],[-.006,.172,.006]],                  // veine cave inférieure (de l'oreillette vers le bas)
  trachee:[[0,.648,.016],[0,.6,-.003],[0,.545,-.02]],broncheD:[[0,.545,-.02],[-.02,.53,-.022],[-.045,.512,-.022]],broncheG:[[0,.545,-.02],[.022,.532,-.024],[.052,.512,-.024]],
  oeso:[[0,.655,-.008],[0,.6,-.024],[.003,.54,-.04],[.006,.47,-.03],[.016,.42,-.012],[.022,.398,0],[.034,.38,.018]]};
const AOD=lisse(CH.aoDesc,4),VCI=lisse(CH.vci,4);
// coupole du diaphragme : hauteur y selon (x, z) ; rho = distance réduite au bord (1 sur les côtes)
const diaRho=(x,z)=>Math.hypot(x/.142,z/.092);
const diaY=(x,z)=>{const rho=Math.min(1,diaRho(x,z)),bord=.31+.085*Math.max(0,z/.092)**2,haut=.424-.09*x-.013*Math.exp(-((x-.02)**2+(z-.03)**2)/.002);return bord+(haut-bord)*(1-Math.pow(rho,2.2))};
// emplacements (centre, rayon) des organes bâtis sur ces trajets
const K={trachee:{c:[.003,.58,-.004],r:.08},oeso:{c:[.014,.517,-.012],r:.145},aorte:{c:[.004,.49,-.012],r:.105},cave:{c:[-.02,.44,.012],r:.15},dia:{c:[0,.385,0],r:.15}};

/* ───────── nouveaux tissus, cellules et molécules ───────── */
const NERF=tis('Nerf périphérique','Un câble vivant : des milliers d\'axones rangés en fascicules, chacun sous sa gaine. Certains portent les ordres du cerveau vers les muscles, d\'autres ramènent le toucher, la chaleur et la douleur vers la moelle.',3e-3,'Nerf');
(()=>{const fs=[[0,0,.2]];for(let i=0;i<6;i++)fs.push([.36*Math.cos(i*TAU/6+.3),.36*Math.sin(i*TAU/6+.3),.15]);
  for(let i=0;i<1300;i++){const a=rnd()*TAU;put(NERF,[.6*Math.cos(a),rs()*.95,.6*Math.sin(a)])}                                             // épinèvre
  fs.forEach(f=>{for(let i=0;i<240;i++){const a=rnd()*TAU;put(NERF,[f[0]+f[2]*Math.cos(a),rs()*.95,f[1]+f[2]*Math.sin(a)])}              // périnèvre de chaque fascicule
    for(let i=0;i<70;i++){const a=rnd()*TAU,r=f[2]*.85*Math.sqrt(rnd());put(NERF,[f[0]+r*Math.cos(a),rs()*.9,f[1]+r*Math.sin(a)],AXONE,.03,0)}});
  for(let i=0;i<6;i++){const a=i*TAU/6+.8;put(NERF,[.5*Math.cos(a),rs()*.6,.5*Math.sin(a)],CAPILLAIRE,.1,RX_Y)}
  for(let i=0;i<60;i++){const a=rnd()*TAU,r=.2+.35*rnd();put(NERF,[r*Math.cos(a),rs()*.9,r*Math.sin(a)],COLLAGENE,.012,0)}phAxe(NERF,1,-1)})();
const INSULINE=node('Insuline','L\'hormone qui fait entrer le sucre du sang dans les cellules. Deux courtes chaînes de 21 et 30 acides aminés, reliées par des ponts de soufre (en jaune). Les cellules bêta du pancréas la libèrent quand la glycémie monte ; quand elle manque, c\'est le diabète.',3e-9,'Protéine · hormone');
(()=>{const chaine=(nb,L,cys)=>{const ps=[];let p=add(L,mulS(inBall(),L[3]*.4)),d=dir(),prev=null;
    for(let i=0;i<nb;i++){d=norm(add(d,mulS(dir(),.8)));let q=add(p,mulS(d,.11));if(dist(q,L)>L[3]){d=norm(add(sub(L,p),mulS(dir(),L[3]*.5)));q=add(p,mulS(d,.11))}
      p=q;put(INSULINE,p,cys.includes(i)?AA[2]:pickOf(AA),.065);if(prev)line(INSULINE,prev,p,5,.004);prev=p;ps.push(p)}return ps};
  const A=chaine(21,[.28,.2,0,.5],[5,6,10,19]),Bc=chaine(30,[-.2,-.12,0,.62],[6,18]);
  INK=E_SOUFRE;[[A[6],Bc[6]],[A[19],Bc[18]],[A[5],A[10]]].forEach(q=>line(INSULINE,q[0],q[1],40,.006));INK=0})();
const ILOT=tis('Îlot de Langerhans','Un amas de cellules endocrines noyé dans le pancréas, traversé de capillaires. Ses cellules bêta fabriquent l\'insuline, stockée en grains, ses cellules alpha le glucagon : à elles deux, elles règlent le sucre du sang. Le pancréas en compte environ un million.',2e-4,'Unité du pancréas');
(()=>{const cs=[];for(let t=0;t<6000&&cs.length<110;t++){const p=mulS(inBall(),.72);if(cs.every(c=>dist(c,p)>.15))cs.push(p)}
  cs.forEach(c=>{for(let i=0;i<14;i++)put(ILOT,add(c,mulS(dir(),.075)));put(ILOT,add(c,mulS(inBall(),.02)),NOYAU,.03);
    for(let i=0;i<5;i++)put(ILOT,add(c,mulS(dir(),.05)),VESICULE,.009);for(let i=0;i<3;i++)put(ILOT,add(c,mulS(dir(),.055)),INSULINE,.004);put(ILOT,add(c,mulS(dir(),.045)),MITO,.012)});
  for(let k=0;k<9;k++){const ps=walk(9,.2,.75);ps.forEach((p,i)=>{if(i)put(ILOT,lerp(ps[i-1],p,.5),CAPILLAIRE,.1,vers(sub(p,ps[i-1]),1))})}
  for(let i=0;i<700;i++)put(ILOT,mulS(dir(),.8+gs()*.015));for(let i=0;i<60;i++)put(ILOT,mulS(dir(),.86+rnd()*.1),INSULINE,.004)})();
const FOLLICULE=tis('Follicule thyroïdien','Une petite sphère creuse : une seule couche de cellules autour d\'une réserve de colloïde, une gelée de thyroglobuline. C\'est là que l\'iode est fixé pour fabriquer les hormones thyroïdiennes, que les capillaires voisins emportent.',2e-4,'Unité de la thyroïde');
(()=>{const n=FOLLICULE;for(let i=0;i<90;i++){const d=dir(),c=mulS(d,.66);for(let k=0;k<10;k++)put(n,add(c,mulS(dir(),.07)));put(n,add(c,mulS(d,-.02)),NOYAU,.035)}
  for(let i=0;i<900;i++)put(n,mulS(dir(),.57));for(let i=0;i<500;i++)put(n,mulS(dir(),.76));
  for(let i=0;i<260;i++)put(n,mulS(inBall(),.54),PROT,.02);
  for(let i=0;i<22;i++){const d=dir();put(n,mulS(d,.86),CAPILLAIRE,.14,vers(perp(d),1))}})();
const CILIEE=cellNode('Cellule ciliée','Le capteur de l\'oreille interne. À son sommet, une touffe de stéréocils rangés en escalier : quand le son ou un mouvement de la tête les incline, des canaux ioniques s\'ouvrent et la cellule prévient le nerf. Tu en as environ 15 000 par cochlée, et elles ne repoussent pas.',3e-5);
(()=>{const n=CILIEE,segs=[{a:[0,-.75,0],b:[0,-.3,0],ra:.2,rb:.3},{a:[0,-.3,0],b:[0,.15,0],ra:.3,rb:.24},{a:[0,.15,0],b:[0,.42,0],ra:.24,rb:.2}];
  fillCell(n,tubes(null,segs,0),{nuc:[0,-.3,0],nucR:.17,mito:26,golgi:0,mt:4,surf:1100,ribo:80});
  for(let i=0;i<220;i++){const r=.2*Math.sqrt(rnd()),a=rnd()*TAU;put(n,[r*Math.cos(a),.42,r*Math.sin(a)])}
  for(let row=0;row<3;row++)for(let k=-5;k<=5;k++){const x=-.07+row*.07-Math.abs(k)*.012,z=k*.03,b=[x,.42,z],t=[x+.04,.56+row*.17,z];
    line(n,b,t,30,.004);put(n,lerp(b,t,.5),ACTINE,.03,vers(sub(t,b)));put(n,t,CANAL,.012)}
  for(let i=0;i<40;i++)put(n,[rs()*.14,-.72+rs()*.05,rs()*.14],VESSYN,.014)})();
const PAPILLE=tis('Papille gustative','Un des petits reliefs qui rendent la langue râpeuse. Dans ses flancs se logent les bourgeons du goût, des bouquets de cellules sensorielles ouverts par un pore : sucré, salé, acide, amer et umami y sont détectés puis transmis au nerf.',1e-3,'Unité de la langue');
(()=>{const n=PAPILLE,R=y=>y<.1?.42:.42+.3*Math.sin(Math.min(1,(y-.1)/.5)*Math.PI/2);
  for(let i=0;i<360;i++){let p,nr;if(rnd()<.6){const y=-.85+rnd()*1.45,a=rnd()*TAU;nr=[Math.cos(a),0,Math.sin(a)];p=[R(y)*nr[0],y,R(y)*nr[2]]}else{const d=dir();d[1]=Math.abs(d[1]);nr=d;p=[.72*d[0],.6+.3*d[1],.72*d[2]]}
    put(n,p,KERATINO,.05,vers(nr))}
  for(let b=0;b<9;b++){const a=b*TAU/9,y=.3+.12*(b%3),ax=[Math.cos(a),0,Math.sin(a)],c=mulS(ax,R(y)-.09);c[1]=y;
    INK=E_GRIS;for(let k=0;k<12;k++){const pp=perp(ax);for(let i=0;i<14;i++){const t=i/13;put(n,add(c,add(mulS(ax,(t-.5)*.16),mulS(pp,.045*Math.sin(Math.PI*t)))))}}INK=0;
    put(n,add(c,mulS(ax,-.1)),AXONE,.035,vers(ax));put(n,add(c,mulS(ax,.085)),CANAL,.012)}
  for(let i=0;i<8;i++){const a=rnd()*TAU,r=.25*rnd();put(n,[r*Math.cos(a),-.7+i*.16,r*Math.sin(a)],CAPILLAIRE,.13,RX_Y)}
  for(let i=0;i<5;i++)put(n,[rs()*.15,-.8+i*.2,rs()*.15],AXONE,.05,0);
  for(let i=0;i<200;i++){const a=rnd()*TAU,r=.3*Math.sqrt(rnd());put(n,[r*Math.cos(a),-.9+rnd()*1.2,r*Math.sin(a)],COLLAGENE,.02,vers([rs(),rs(),rs()]))}})();
const OVOCYTE=cellNode('Ovocyte','La plus grosse cellule du corps humain, visible à l\'œil nu : un dixième de millimètre. Elle porte la moitié du patrimoine génétique de la mère et toutes les réserves de départ de l\'embryon, sous une coque transparente, la zone pellucide.',1.2e-4);
(()=>{const n=OVOCYTE;fillCell(n,blob(.62,1,.02),{nuc:[.12,.08,0],nucR:.2,mito:130,ribo:200,ves:60,surf:1100,memb:.15,lyso:6,mt:6});
  for(let i=0;i<1700;i++)put(n,mulS(dir(),.7+rnd()*.07));
  for(let i=0;i<46;i++){const c=mulS(dir(),.87);for(let k=0;k<12;k++)put(n,add(c,mulS(dir(),.06)));put(n,c,NOYAU,.03)}})();
const SPERMATO=cellNode('Spermatozoïde','Une cellule réduite à l\'essentiel : une tête qui porte l\'ADN du père, serré au maximum sous un capuchon d\'enzymes ; une pièce intermédiaire bourrée de mitochondries ; et un flagelle qui la propulse. Il s\'en fabrique environ mille par seconde.',5.5e-5);
(()=>{const n=SPERMATO;for(let i=0;i<700;i++){const d=dir();put(n,[d[0]*.06,.84+d[1]*.1,d[2]*.035])}
  INK=E_PALE;for(let i=0;i<500;i++){const d=dir();if(d[1]<.1)continue;put(n,[d[0]*.066,.84+d[1]*.108,d[2]*.04])}INK=0;                      // acrosome
  for(let i=0;i<60;i++){const d=dir();if(d[1]<.2)continue;put(n,[d[0]*.05,.84+d[1]*.09,d[2]*.028],ENZYME,.012)}
  for(let i=0;i<46;i++){const d=inBall();put(n,[d[0]*.045,.82+d[1]*.07,d[2]*.025],ADN,.02)}
  for(let i=0;i<34;i++){const t=i/33,a=t*TAU*8;put(n,[.03*Math.cos(a),.72-t*.2,.03*Math.sin(a)],MITO,.022)}
  const f=y=>[.045*Math.sin(y*9)*(.74-y),y,.02*Math.sin(y*5+1)*(.74-y)];
  for(let i=0;i<2200;i++){const y=.74-rnd()*1.7,p=f(y),a=rnd()*TAU,r=y>.52?.045:.014;put(n,[p[0]+r*Math.cos(a),y,p[2]+r*Math.sin(a)])}
  for(let i=0;i<40;i++){const y=.5-i*1.44/39,p=f(y);put(n,p,MICROTUBULE,.03,vers(sub(p,f(y-.02))))}
  put(n,[0,.735,0],MICROTUBULE,.02,RX_Y);for(let i=0;i<30;i++)put(n,[rs()*.02,.7-rnd()*.2,rs()*.02],ATP,.004)})();

/* ───────── nouveaux organes ───────── */
const MUSCLE=org('Muscle squelettique','Un muscle entier, celui qui obéit à ta volonté : un fuseau de faisceaux parallèles, prolongé à chaque bout par un tendon de collagène qui l\'attache à l\'os. Un nerf lui apporte les ordres, des vaisseaux le sucre et l\'oxygène. Tu en as plus de 600.',.3);
(()=>{const n=MUSCLE,R=y=>.3*Math.pow(Math.max(0,Math.cos(y/.66*Math.PI/2)),.6),AX=aimX([0,1,0]);
  for(let i=0;i<1700;i++){const y=rs()*.64,a=rnd()*TAU,r=R(y)*Math.sqrt(rnd())*.93;put(n,[r*Math.cos(a),y,r*Math.sin(a)],FAISCEAU,.02,AX)}
  for(let i=0;i<900;i++){const y=rs()*.66,a=rnd()*TAU;put(n,[R(y)*Math.cos(a),y,R(y)*Math.sin(a)])}
  INK=E_TEND;for(const s of[-1,1])for(let i=0;i<450;i++){const t=rnd(),a=rnd()*TAU,r=(.11-.07*t)*Math.sqrt(rnd());put(n,[r*Math.cos(a),s*(.56+t*.39),r*Math.sin(a)])}INK=0;
  for(const s of[-1,1])for(let i=0;i<50;i++){const t=rnd(),a=rnd()*TAU,r=(.1-.06*t)*Math.sqrt(rnd());put(n,[r*Math.cos(a),s*(.58+t*.36),r*Math.sin(a)],COLLAGENE,.012,0)}
  for(let i=0;i<7;i++){const a=i*2.4;put(n,[.12*Math.cos(a),-.45+i*.15,.12*Math.sin(a)],VAISSEAU,.035,0)}
  semer(n,lisse([[.75,.3,.1],[.45,.2,.05],[.2,.08,0],[.05,-.05,0]],4),.012,.012,14,NERF,.03,{axe:'y'})})();
const MOELLE=org('Moelle épinière','Le câble qui relie le cerveau au corps, logé dans la colonne : 45 cm de long, gros comme un doigt. Ici un tronçon : au centre le papillon de substance grise, autour la substance blanche des faisceaux montants et descendants, et à chaque étage une paire de nerfs. Il y en a 31 paires.',.06);
(()=>{const n=MOELLE,inH=(x,z)=>{x=Math.abs(x);return(Math.abs(z)<.022&&x<.075)||((x-.07)/.04)**2+((z-.055)/.055)**2<1||((x-.062)/.022)**2+((z+.065)/.07)**2<1};
  let k=0;while(k<750){const x=rs()*.2,z=rs()*.165;if((x/.2)**2+(z/.165)**2>1||inH(x,z))continue;put(n,[x,rs()*.92,z],SBLANCHE,.022,RX_Y);k++}
  k=0;while(k<380){const x=rs()*.12,z=rs()*.14;if(!inH(x,z))continue;put(n,[x,rs()*.92,z],NEURONE,.016);k++}
  INK=E_GRIS;k=0;while(k<1000){const x=rs()*.12,z=rs()*.14;if(!inH(x,z))continue;put(n,[x,rs()*.92,z]);k++}INK=0;
  for(let i=0;i<900;i++){const a=rnd()*TAU;put(n,[.2*Math.cos(a),rs()*.93,.165*Math.sin(a)])}
  INK=E_PALE;for(let i=0;i<700;i++){const a=rnd()*TAU;put(n,[.34*Math.cos(a),rs()*.95,.29*Math.sin(a)])}INK=0;                             // dure-mère
  for(let i=0;i<9;i++)put(n,[0,-.85+i*.21,.175],VAISSEAU,.022,0);
  for(const y0 of[.66,.22,-.22,-.66])for(const s of[-1,1]){
    const dr=lisse([[s*.085,y0,-.14],[s*.25,y0-.04,-.15],[s*.42,y0-.09,-.1],[s*.56,y0-.12,-.05]],4),vr=lisse([[s*.09,y0,.13],[s*.26,y0-.05,.1],[s*.44,y0-.1,0],[s*.56,y0-.12,-.05]],4),
      sn=lisse([[s*.56,y0-.12,-.05],[s*.75,y0-.16,-.03],[s*.93,y0-.2,-.02]],4);
    INK=E_NERF;semer(n,dr,.02,.02,60);semer(n,vr,.02,.02,60);semer(n,sn,.03,.03,50);INK=0;
    semer(n,dr,.01,.01,7,NERF,.03,{axe:'y'});semer(n,vr,.01,.01,7,NERF,.03,{axe:'y'});semer(n,sn,.012,.012,7,NERF,.04,{axe:'y'});
    for(let i=0;i<26;i++)put(n,add([s*.42,y0-.09,-.1],mulS(inBall(),.06)),NEURONE,.014)}                                                    // ganglion spinal : corps des neurones sensitifs
  phAxe(n,1,-1)})();
// conduit aérien : anneaux de cartilage en fer à cheval ouverts vers l'arrière, muqueuse, air
function conduitAerien(n,pts,R,nbA,ph0){const T=longueur(pts);
  for(let k=0;k<nbA;k++){const o=auLong(pts,(k+.5)/nbA*T),bk=norm(sub([0,0,-1],mulS(o.t,-o.t[2]))),sd=cross(o.t,bk);PH=ph0+(k+.5)/nbA*T;
    INK=E_CART;for(let i=0;i<46;i++){const a=rs()*2.3;put(n,add(o.p,add(mulS(bk,-R*Math.cos(a)),add(mulS(sd,R*Math.sin(a)),mulS(o.t,gs()*.008)))))}INK=0;
    for(let i=0;i<3;i++){const a=rs()*2.2;put(n,add(o.p,add(mulS(bk,-R*Math.cos(a)),mulS(sd,R*Math.sin(a)))),COLLAGENE,.012,vers(sd))}}
  INK=E_AIR;semer(n,pts,R*.96,R*.96,Math.round(T*520),undefined,0,{ph:ph0});INK=0;
  semer(n,pts,R*.9,R*.9,Math.round(T*22),CAPILLAIRE,.03,{axe:'x',ph:ph0});
  semer(n,pts,R*.8,R*.8,Math.round(T*70),O2,.006,{plein:1,ph:ph0});semer(n,pts,R*.8,R*.8,Math.round(T*26),CO2,.006,{plein:1,ph:ph0});return ph0+T}
const TRACHEE=org('Trachée','Le tuyau de l\'air, du larynx aux poumons : 11 cm, tenu ouvert par une vingtaine d\'anneaux de cartilage en fer à cheval. En bas, elle se divise en deux bronches souches, une par poumon ; la droite est plus courte et plus verticale.',.145);
(()=>{const n=TRACHEE,L=loc(K.trachee.c,K.trachee.r),e=conduitAerien(n,lisse(CH.trachee.map(L),5),.13,18,.03);
  conduitAerien(n,lisse(CH.broncheD.map(L),4),.1,6,e);conduitAerien(n,lisse(CH.broncheG.map(L),4),.09,8,e)})();
const LARYNX=org('Larynx','Le carrefour de la gorge : il aiguille l\'air vers la trachée et ferme la porte aux aliments grâce à l\'épiglotte. Dans son armature de cartilages sont tendues les deux cordes vocales, qui vibrent au passage de l\'air : c\'est ta voix.',.05);
(()=>{const n=LARYNX;INK=E_CART;
  let k=0;while(k<1100){const s=rnd()<.5?-1:1,u=rnd(),v=rnd(),y=-.32+v*.72;if(y>.4-.6*Math.max(0,.3-u))continue;put(n,[s*(.03+(.38+.14*v)*u),y+.1*u,.6-.78*u]);k++}                  // cartilage thyroïde : deux lames en V
  for(const s of[-1,1]){line(n,[s*.55,.5,-.18],[s*.5,.8,-.22],40,.012);line(n,[s*.41,-.22,-.18],[s*.38,-.5,-.2],30,.012)}                               // cornes
  for(let i=0;i<700;i++){const a=rnd()*TAU,bk=Math.max(0,-Math.sin(a));put(n,[.36*Math.cos(a),-.78+rnd()*(.22+.42*bk),.36*Math.sin(a)+.1])}               // cricoïde : anneau en chevalière
  for(let i=0;i<500;i++){const t=rnd(),w=.3*Math.sin(Math.PI*Math.min(1,t*1.15))*(rs());put(n,[w,.12+.83*t,.42-.3*t-.5*w*w])}                             // épiglotte
  for(const s of[-1,1])for(let i=0;i<70;i++)put(n,add([s*.16,-.02,-.2],mulS(inBall(),.07)));                                                               // aryténoïdes
  INK=0;for(let i=0;i<70;i++){const a=rs()*1.75;put(n,[.5*Math.sin(a)+gs()*.01,.9+gs()*.02,.5*Math.cos(a)-.05],OSTEON,.03)}                                // os hyoïde
  for(let i=0;i<90;i++){const s=i%2?1:-1,u=rnd(),y=-.35+rnd()*.7;put(n,[s*(.06+.48*u),y+.1*u,.6-.75*u],COLLAGENE,.012,vers([rs(),rs(),rs()]))}
  for(const s of[-1,1]){const a=[s*.012,-.05,.5],b=[s*.15,-.05,-.18];INK=E_DENT;line(n,a,b,160,.008);INK=0;                                                // cordes vocales
    for(let i=0;i<14;i++){const t=(i+.5)/14;put(n,add(lerp(a,b,t),[s*.05,-.03,0]),FAISCEAU,.03,vers(sub(b,a),1))}
    for(let i=0;i<5;i++)put(n,[s*(.1+.05*i),-.42+rs()*.05,.42-.07*i],FAISCEAU,.03,vers([0,1,-.3],1));put(n,[s*.3,-.5,-.25],NERF,.03,vers([0,1,0]));
    for(let i=0;i<10;i++){const a=rnd()*TAU;put(n,[s*Math.abs(.3*Math.cos(a)),-.3+rnd()*.6,.1+.3*Math.sin(a)],CAPILLAIRE,.03)}}
  INK=E_AIR;for(let i=0;i<260;i++){const a=rnd()*TAU;put(n,[.27*Math.cos(a),-.98+rnd()*.2,.27*Math.sin(a)+.1])}INK=0;phAxe(n,1,-1)})();
const OESOPHAGE=org('Œsophage','Un tube musclé de 25 cm entre la gorge et l\'estomac, derrière la trachée. Il ne digère rien : il pousse. Une vague de contraction descend et fait avancer la bouchée en quelques secondes, même la tête en bas. Son tiers supérieur est fait de muscle strié, le reste de muscle lisse.',.26);
(()=>{const n=OESOPHAGE,P=lisse(CH.oeso.map(loc(K.oeso.c,K.oeso.r)),5),R=.06,T=longueur(P),haut=P.slice(0,Math.round(P.length*.36)),ph=.9;
  INK=E_DIG;semer(n,P,R,R,1500,undefined,0,{ph});semer(n,P,R*.4,R*.4,500,undefined,0,{ph});
  for(const u of[.015,.985])for(let i=0;i<220;i++){const o=auLong(P,u*T+gs()*.01);PH=ph+u*T;put(n,add(o.p,mulS(perp(o.t),R*(1.05+.12*rnd()))))}PH=0;INK=0;   // sphincters
  semer(n,haut,R,R,170,FAISCEAU,.016,{axe:'x',ph});semer(n,P,R*1.05,R*1.05,60,CAPILLAIRE,.02,{axe:'x',ph});semer(n,P,R*1.3,R*1.3,10,NERF,.02,{axe:'y',ph})})();
const DIAPHRAGME=org('Diaphragme','Le muscle de la respiration : une coupole qui sépare le thorax de l\'abdomen. En se contractant, il s\'abaisse et les poumons se remplissent ; en se relâchant, il remonte. Ses fibres rayonnent d\'un tendon central, percé pour laisser passer l\'aorte, la veine cave et l\'œsophage.',.27);
(()=>{const n=DIAPHRAGME,L=loc(K.dia.c,K.dia.r),trou=(x,z)=>Math.hypot(x+.024,z-.01)<.014||Math.hypot(x-.02,z+.002)<.011||Math.hypot(x-.012,z+.045)<.016;
  let k=0;while(k<2600){const x=rs()*.142,z=rs()*.092,rho=diaRho(x,z);if(rho>1||trou(x,z))continue;const p=L([x,diaY(x,z),z]),tendon=rho<.42+.1*Math.cos(3*Math.atan2(z,x)+1.6);k++;
    if(tendon){if(rnd()<.06)put(n,p,COLLAGENE,.012,vers([x,0,z]));else{INK=E_TEND;put(n,p);INK=0}}
    else if(rnd()<.45)put(n,p,FAISCEAU,.016,vers([x,(diaY(x*1.05,z*1.05)-diaY(x,z))*8,z],1));else put(n,p)}
  for(const s of[-1,1]){const cr=lisse([[s*.03,.325,-.075],[s*.02,.3,-.05],[s*.012,.27,-.03],[s*.008,.245,-.022]].map(L),4);semer(n,cr,.05,.02,260,undefined,0,{plein:1});semer(n,cr,.04,.02,26,FAISCEAU,.016,{axe:'x'})}   // piliers
  for(const s of[-1,1])put(n,L([s*.05,diaY(s*.05,.03)+.004,.03]),NERF,.025,vers([0,1,0]));for(let i=0;i<30;i++){const x=rs()*.12,z=rs()*.08;if(diaRho(x,z)<.95)put(n,L([x,diaY(x,z),z]),CAPILLAIRE,.02)}})();
// organe plein le long d'une ligne médiane [x,y,z,rayon] : fn(point intérieur, point de surface, axe)
const boudin=(n,Q,k,nb,fn,fz=1)=>{const P=lisse(Q,k),R=P.map(p=>p[3]);tube(n,P.map(p=>p.slice(0,3)),R,nb,(p,nr,c,r)=>{const d=[nr[0],nr[1],nr[2]*fz];fn(add(c,mulS(d,r*Math.cbrt(rnd()))),add(c,mulS(d,r)),nr)});return P};
const PANCREAS=org('Pancréas','Une glande allongée, cachée derrière l\'estomac. Double métier : elle déverse dans l\'intestin les enzymes qui digèrent le repas, et libère dans le sang, par ses îlots, l\'insuline et le glucagon qui règlent le sucre.',.15);
(()=>{const n=PANCREAS,Q=[[-.6,-.42,0,.09],[-.64,-.14,0,.26],[-.42,.02,.02,.2],[-.15,.08,.05,.16],[.25,.14,0,.15],[.6,.22,-.03,.12],[.9,.3,-.05,.05]];
  const P=boudin(n,Q,5,2900,(q,s)=>{const u=rnd();u<.1?put(n,q,ILOT,.014):u<.125?put(n,q,CAPILLAIRE,.02):u<.6?put(n,[q[0]+.012*Math.sin(q[1]*70),q[1]+.012*Math.sin(q[0]*70),q[2]]):put(n,s)},.6);
  INK=E_DENT;semer(n,P.slice(5),.008,.008,260);INK=0;                                                                                        // canal de Wirsung
  for(let i=0;i<10;i++){const p=P[8+i*2];put(n,[p[0],p[1]+p[3]*.8,p[2]-.06],VAISSEAU,.035,vers([1,.2,0]))}})();
const RATE=org('Rate','Un filtre à sang gros comme le poing, sous les côtes gauches. Sa pulpe rouge retire de la circulation les globules rouges usés ; sa pulpe blanche, pleine de lymphocytes, surveille le sang et lance la riposte contre les microbes qui s\'y trouvent.',.12);
(()=>{const n=RATE,F=d=>[d[0]*.46+.12*(1-d[1]*d[1])-.05,d[1]*.85,d[2]*.36],hile=p=>dist(p,[-.62,0,.05])<.4;
  let k=0;while(k<1200){const p=F(dir());if(hile(p))continue;put(n,[p[0],p[1]+.02*Math.sin(p[2]*30)*(p[1]>.5?1:0),p[2]]);k++}
  for(let i=0;i<260;i++){const d=dir(),p=add([-.62,0,.05],mulS(d,.4)),q=[(p[0]+.05-.12*(1-(p[1]/.85)**2))/.46,p[1]/.85,p[2]/.36];if(len(q)<1)put(n,p)}
  k=0;while(k<1100){const p=F(inBall());if(hile(p))continue;put(n,p,RBC,.007);k++}
  k=0;while(k<34){const c=F(mulS(inBall(),.8));if(hile(c))continue;k++;put(n,c,CAPILLAIRE,.03);for(let i=0;i<17;i++)put(n,add(c,mulS(inBall(),.06)),LYMPHO,.009)}
  for(let i=0;i<8;i++)put(n,[-.3+rs()*.05,-.4+i*.11,.05+rs()*.05],VAISSEAU,.05,vers([1,rs()*.5,0]))})();
const VESBIL=org('Vésicule biliaire','Une petite poire verte sous le foie. Elle met en réserve la bile que le foie fabrique sans arrêt, la concentre, puis la chasse dans l\'intestin quand un repas gras arrive : la bile disperse les graisses en gouttelettes que les enzymes peuvent attaquer.',.08);
(()=>{const n=VESBIL,Q=[[-.34,.93,0,.035],[-.26,.74,0,.05],[-.14,.45,0,.15],[.02,0,0,.3],[.1,-.4,0,.34],[.14,-.62,0,.3]];
  INK=E_LYMPH;const P=boudin(n,Q,5,1700,(q,s)=>put(n,s));for(let i=0;i<420;i++){const d=dir();if(d[1]>0)continue;put(n,[.14+d[0]*.3,-.62+d[1]*.26,d[2]*.3])}
  for(let k=0;k<5;k++)for(let i=0;i<50;i++){const a=rnd()*TAU;put(n,[-.3+k*.035+.06*Math.cos(a),.85-k*.07,.06*Math.sin(a)])}INK=0;           // valves spirales du canal cystique
  boudin(n,Q.slice(2),4,300,(q,s)=>{const u=rnd();u<.12?put(n,s,CAPILLAIRE,.025):u<.6?put(n,q,EAU,.004):0})})();
const VESSIE=org('Vessie','Un réservoir musculaire extensible. L\'urine y arrive goutte à goutte des reins par les deux uretères ; à partir de 300 ml environ, sa paroi étirée prévient le cerveau. Quand tu le décides, le muscle de la paroi se contracte et l\'urètre s\'ouvre.',.1);
(()=>{const n=VESSIE,S=d=>[d[0]*.66,.06+d[1]*.6,d[2]*.6];
  for(let i=0;i<1400;i++)put(n,S(dir()));INK=E_URI;for(let i=0;i<900;i++){const d=dir(),w=.84+.03*Math.sin(d[0]*17)*Math.sin(d[1]*13+d[2]*15);put(n,mulS(S(d),w))}INK=0;
  for(let i=0;i<150;i++){const d=dir();put(n,mulS(S(d),.93),FAISCEAU,.022,vers(perp(d),1))}for(let i=0;i<60;i++)put(n,mulS(S(dir()),.9),CAPILLAIRE,.02);
  for(let i=0;i<110;i++)put(n,mulS(S(inBall()),.75),EAU,.004);
  for(const s of[-1,1]){INK=E_URI;semer(n,lisse([[s*.62,.95,-.5],[s*.5,.6,-.55],[s*.3,.2,-.5],[s*.2,-.1,-.4]],4),.035,.035,260);INK=0}
  INK=E_URI;semer(n,[[0,-.5,.05],[0,-.97,.12]],.05,.04,220);for(let i=0;i<160;i++){const a=rnd(),b=rnd()*(1-a);put(n,[.2*(a-b)*1.6,-.1-.4*(1-a-b),-.4+.42*(1-a-b)])}INK=0})();   // urètre, trigone
const THYROIDE=org('Thyroïde','Une glande en forme de papillon, posée sur la trachée à la base du cou. Ses hormones, bâties avec l\'iode de l\'alimentation, règlent la vitesse à laquelle toutes tes cellules consomment de l\'énergie : température, rythme du cœur, croissance.',.055);
(()=>{const n=THYROIDE;for(const s of[-1,1]){const c=[s*.52,.08,-.12],r=[.27,.62,.25],F=d=>[c[0]+d[0]*r[0]+s*.1*d[1],c[1]+d[1]*r[1],c[2]+d[2]*r[2]-.1*d[1]*d[1]];
    for(let i=0;i<650;i++)put(n,F(inBall()),FOLLICULE,.032);for(let i=0;i<500;i++)put(n,F(dir()));for(let i=0;i<26;i++)put(n,F(mulS(dir(),.9)),CAPILLAIRE,.03);
    put(n,F([0,1.05,0]),VAISSEAU,.05,vers([s*.3,1,0]));put(n,F([0,-1.05,0]),VAISSEAU,.05,vers([s*.6,-1,-.3]))}
  for(let i=0;i<260;i++){const d=inBall();put(n,[d[0]*.3,-.22+d[1]*.16,.13+d[2]*.1-.3*d[0]*d[0]],FOLLICULE,.032)}
  for(let i=0;i<260;i++){const d=dir();put(n,[d[0]*.3,-.22+d[1]*.16,.13+d[2]*.1-.3*d[0]*d[0]])}})();
const SURRENALE=org('Glande surrénale','Un petit chapeau posé sur chaque rein. Son écorce jaune fabrique le cortisol et l\'aldostérone, qui gèrent le stress long, le sucre et le sel ; son cœur, relié directement aux nerfs, lâche l\'adrénaline en une fraction de seconde.',.05);
(()=>{const n=SURRENALE,top=u=>.55*(1-Math.pow(Math.abs(u),1.5)),bot=u=>-.38+.26*(1-u*u),zm=u=>.15*(1-.5*Math.abs(u));
  for(let i=0;i<3400;i++){const u=rs(),v=rnd(),w=rs(),t=top(u),b=bot(u);if(t-b<.02)continue;const prof=Math.min(v,1-v,1-Math.abs(w),(1-Math.abs(u))*1.5),p=[u*.8,b+(t-b)*v,w*zm(u)],e=rnd();
    if(e<.04)put(n,p,CAPILLAIRE,.022);else if(prof>.3&&e<.12)put(n,p,VESICULE,.008);else{INK=prof>.3?E_PAROI:prof<.06?0:E_JAUNE;put(n,p);INK=0}}
  for(let i=0;i<4;i++)put(n,[-.3+i*.2,.02,0],NERF,.03,vers([rs(),-1,rs()]));for(let i=0;i<3;i++)put(n,[-.2+i*.2,.08,.02],VAISSEAU,.05,vers([1,0,0]))})();
const THYMUS=org('Thymus','L\'école des lymphocytes T, derrière le sternum. Ils y apprennent à distinguer ce qui t\'appartient de ce qui t\'est étranger ; ceux qui se trompent sont éliminés. Très actif dans l\'enfance, il se réduit peu à peu en graisse à l\'âge adulte.',.055);
(()=>{const n=THYMUS;for(const s of[-1,1]){const F=d=>[s*.24+d[0]*.24+s*.08*d[1],d[1]*.85-.02,d[2]*.2-.12*d[1]*d[1]];
    for(let i=0;i<500;i++)put(n,F(dir()));
    for(let L=0;L<13;L++){const c=F(mulS(inBall(),.8));for(let i=0;i<62;i++)put(n,add(c,mulS(dir(),.09+.03*rnd())),LYMPHO,.014);for(let i=0;i<10;i++)put(n,add(c,mulS(inBall(),.07)),LYMPHO,.014);
      for(let i=0;i<24;i++)put(n,add(c,mulS(dir(),.13)));put(n,c,CAPILLAIRE,.035)}}})();
const GANGLION=org('Ganglion lymphatique','Un poste de contrôle sur le trajet de la lymphe, gros comme un haricot. Les lymphocytes y attendent, groupés en follicules ; si la lymphe apporte un microbe, ils se multiplient et fabriquent des anticorps : c\'est pourquoi le ganglion gonfle. Tu en as plusieurs centaines.',.012);
(()=>{const n=GANGLION,F=d=>[d[0]*.5+.14*(1-d[1]*d[1]),d[1]*.85,d[2]*.42],hile=p=>dist(p,[-.58,0,0])<.33;
  let k=0;while(k<1100){const p=F(dir());if(!hile(p)){put(n,p);k++}}
  for(let i=0;i<13;i++){const a=-1.25+i*2.5/12,c=[.28*Math.cos(a)+.14*(1-Math.sin(a)**2)*.6+.02,.62*Math.sin(a),rs()*.12];
    for(let j=0;j<60;j++)put(n,add(c,mulS(inBall(),.1)),LYMPHO,.02);for(let j=0;j<40;j++)put(n,add(c,mulS(dir(),.115)))}
  k=0;while(k<170){const p=F(mulS(inBall(),.6));if(hile(p)||p[0]>.1)continue;rnd()<.35?put(n,p,LYMPHO,.02):put(n,p,ANTICORPS,.005);k++}
  INK=E_LYMPH;for(let i=0;i<5;i++){const a=-1+i*.5,b=F([Math.cos(a),Math.sin(a),0]);line(n,b,mulS(b,1.45),50,.012)}line(n,[-.25,0,0],[-.95,-.1,0],90,.02);INK=0;   // vaisseaux lymphatiques afférents et efférent
  put(n,[-.4,.1,.05],VAISSEAU,.07,vers([1,0,0]));put(n,[-.4,-.1,-.05],VAISSEAU,.07,vers([1,0,0]));for(let i=0;i<18;i++)put(n,F(mulS(inBall(),.7)),CAPILLAIRE,.03)})();
const HYPOPHYSE=org('Hypophyse','Une glande de la taille d\'un pois, suspendue sous le cerveau, qui commande presque toutes les autres : thyroïde, surrénales, ovaires ou testicules, croissance, lait. Son lobe antérieur fabrique ses propres hormones ; son lobe postérieur libère celles que lui envoie l\'hypothalamus.',.012);
(()=>{const n=HYPOPHYSE,A=d=>[d[0]*.55,-.3+d[1]*.42,.2+d[2]*.42],Pp=d=>[d[0]*.36,-.28+d[1]*.34,-.42+d[2]*.28];
  for(let i=0;i<800;i++)put(n,A(dir()));for(let i=0;i<500;i++)put(n,Pp(dir()));
  for(let i=0;i<120;i++)put(n,A(inBall()),CAPILLAIRE,.035);for(let i=0;i<220;i++)put(n,A(inBall()),VESICULE,.012);for(let i=0;i<120;i++)put(n,A(inBall()),PROT,.006);
  for(let i=0;i<40;i++)put(n,Pp(inBall()),ASTRO,.03);for(let i=0;i<70;i++)put(n,Pp(inBall()),VESICULE,.012);for(let i=0;i<30;i++)put(n,Pp(inBall()),CAPILLAIRE,.035);
  const tige=lisse([[0,.95,-.05],[0,.5,-.1],[0,.1,-.25],[0,-.1,-.4]],4);semer(n,tige,.12,.09,420);INK=E_NERF;semer(n,tige,.06,.05,300,undefined,0,{plein:1});INK=0;   // tige pituitaire et ses axones
  semer(n,tige,.13,.1,10,CAPILLAIRE,.035,{axe:'x'})})();
put(CERVEAU,[0,-.407,.157],HYPOPHYSE,.065,0);      // l'hypophyse pend sous le cerveau : on la retrouve aussi depuis lui
const LANGUE=org('Langue','Un muscle sans os, fait de fibres croisées dans les trois directions : c\'est ce qui lui permet de s\'allonger, de se creuser et de se tordre pour parler, mâcher et avaler. Sa surface est couverte de papilles ; environ 5 000 bourgeons du goût y sont logés.',.1);
(()=>{const n=LANGUE,av=z=>Math.max(0,Math.min(1,(z-.3)/.62)),w=z=>z>.3?.46*Math.sqrt(Math.max(.02,1-Math.pow(av(z),2.2))):.46-.12*Math.max(0,(-.3-z)/.55),
    c=z=>z<-.35?-1.1*Math.pow(-.35-z,1.25):0,ht=z=>.2-.14*av(z),hb=z=>.16-.12*av(z),bo=(x,z)=>Math.sqrt(Math.max(0,1-(x/w(z))**2));
  let k=0;while(k<1250){const z=-.85+rnd()*1.76,x=rs()*w(z)*.97,y=c(z)+ht(z)*bo(x,z)+.005,vx=Math.abs(x)-(z+.5)*1.7;
    if(z>-.52&&z<-.3&&Math.abs(vx)<.04){if(rnd()<.3){put(n,[x,y+.01,z],PAPILLE,.045,0);k++}continue}                                         // V des grosses papilles caliciformes
    if(Math.abs(x)<.012&&z>-.25)continue;put(n,[x,y,z],PAPILLE,.018,0);k++}                                                                  // sillon médian
  for(let i=0;i<1100;i++){const z=-.85+rnd()*1.76,x=rs()*w(z);put(n,[x,c(z)-hb(z)*bo(x,z),z])}                                              // face inférieure
  for(let i=0;i<600;i++){const z=-.8+rnd()*1.6,x=rs()*w(z)*.85;put(n,[x,c(z)+(-hb(z)+(ht(z)+hb(z))*rnd())*bo(x,z)*.85,z],FAISCEAU,.03,vers(i%3===0?[0,0,1]:i%3===1?[1,0,0]:[0,1,0],1))}
  for(let i=0;i<36;i++){const z=-.7+rnd()*1.4;put(n,[rs()*w(z)*.7,c(z)-hb(z)*.5,z],CAPILLAIRE,.03)}
  for(const s of[-1,1])semer(n,lisse([[s*.2,c(-.85)-.1,-.85],[s*.2,-.1,-.4],[s*.18,-.05,.2],[s*.1,0,.7]],4),.01,.01,8,NERF,.03,{axe:'y'})})();
const OREILLE=org('Oreille interne','Un labyrinthe creusé dans l\'os le plus dur du corps. La cochlée, enroulée en colimaçon, trie les sons du grave à l\'aigu le long de sa spirale ; les trois canaux semi-circulaires, à angle droit, mesurent les rotations de la tête. Partout, des cellules ciliées font la traduction pour le nerf.',.02);
(()=>{const n=OREILLE,C=[.3,-.22,.25],A=norm([.5,-.15,.85]),U=norm(cross(A,[0,1,0])),Vv=cross(A,U),V0=[-.15,.05,-.1];
  const spi=t=>{const a=t*2.6*TAU,ro=.34*(1-.62*t);return add(C,add(mulS(A,t*.36),add(mulS(U,ro*Math.cos(a)),mulS(Vv,ro*Math.sin(a)))))};
  for(let i=0;i<1700;i++){const t=rnd(),p=spi(t),tg=norm(sub(spi(t+.004),p));put(n,add(p,mulS(perp(tg),.1*(1-.45*t))))}
  for(let i=0;i<320;i++){const t=i/319,p=spi(t),ax=add(C,mulS(A,t*.36));put(n,lerp(p,ax,.22),CILIEE,.012,vers(A))}                           // organe de Corti
  for(let i=0;i<60;i++){const t=i/59,p=spi(t),ax=add(C,mulS(A,t*.36));put(n,lerp(p,ax,.7),NEURONE,.014)}                                     // ganglion spiral
  for(let i=0;i<420;i++)put(n,surEll(V0,[.2,.17,.15]));                                                                                      // vestibule
  const canal=(c,e1,e2)=>{for(let i=0;i<520;i++){const a=.35+rnd()*5.6,p=add(c,add(mulS(e1,.27*Math.cos(a)),mulS(e2,.27*Math.sin(a)))),tg=norm(add(mulS(e1,-Math.sin(a)),mulS(e2,Math.cos(a))));
      put(n,add(p,mulS(perp(tg),a<.9?.07:.035)))}
    for(let i=0;i<12;i++)put(n,add(c,add(mulS(e1,.27*Math.cos(.6)+rs()*.03),mulS(e2,.27*Math.sin(.6)+rs()*.03))),CILIEE,.012)};
  const q=Math.SQRT1_2;canal([-.3,.33,-.05],[q,0,q],[0,1,0]);canal([-.42,.2,-.35],[q,0,-q],[0,1,0]);canal([-.5,.02,-.2],[-1,0,0],[0,.26,-.97]);
  for(let i=0;i<40;i++)put(n,dansEll(V0,[.12,.1,.09]),CILIEE,.012);for(let i=0;i<80;i++)put(n,dansEll(V0,[.18,.15,.13]),EAU,.004);
  const nf=lisse([[.3,-.22,.25],[.0,-.3,.3],[-.4,-.42,.4],[-.85,-.5,.45]],4);INK=E_NERF;semer(n,nf,.06,.07,360,undefined,0,{plein:1});INK=0;semer(n,nf,.03,.03,11,NERF,.04,{axe:'y'})})();
const UTERUS=org('Utérus','Une poire creuse aux parois de muscle épais. Chaque mois sa muqueuse s\'épaissit pour accueillir un embryon, puis se détache si aucun ne vient : ce sont les règles. De chaque côté, une trompe capte l\'ovule libéré par l\'ovaire ; c\'est là qu\'a lieu la fécondation.',.11);
(()=>{const n=UTERUS,W=y=>y>-.2?.2+.27*Math.sin(Math.min(1,(y+.2)/.7)*Math.PI/2):.2+.06*Math.sin((y+.2)/.6*Math.PI),S=(y,a,k)=>[W(y)*k*Math.cos(a),y,.3*(W(y)/.47)**.7*k*Math.sin(a)];
  for(let i=0;i<1500;i++){const y=-.8+rnd()*1.3;put(n,S(y,rnd()*TAU,1))}for(let i=0;i<300;i++){const d=dir();if(d[1]<0)continue;put(n,[d[0]*.47,.5+d[1]*.13,d[2]*.3])}
  INK=E_REPRO;for(let i=0;i<700;i++){const y=-.75+rnd()*1.15;put(n,S(y,rnd()*TAU,.38))}INK=0;                                                // cavité tapissée par l'endomètre
  for(let i=0;i<170;i++){const y=-.7+rnd()*1.15,a=rnd()*TAU;put(n,S(y,a,.72),FAISCEAU,.025,vers([-Math.sin(a),.3,Math.cos(a)],1))}
  for(let i=0;i<110;i++){const y=-.6+rnd()*1.05;put(n,S(y,rnd()*TAU,.48),CAPILLAIRE,.022)}
  for(const s of[-1,1]){for(let i=0;i<6;i++)put(n,[s*(W(-.5+i*.18)+.05),-.5+i*.18,0],VAISSEAU,.04,vers([0,1,0]));
    const tr=lisse([[s*.42,.42,0],[s*.62,.52,-.03],[s*.82,.5,-.08],[s*.93,.36,-.12],[s*.9,.2,-.12]],5);semer(n,tr,.03,.06,520);semer(n,tr,.02,.04,16,CAPILLAIRE,.02,{axe:'x'});
    INK=E_REPRO;for(let i=0;i<14;i++){const d=dir();line(n,[s*.9,.2,-.12],add([s*.9,.2,-.12],[d[0]*.1,-.06-.08*rnd(),d[2]*.1]),14,.004)}INK=0}   // pavillon frangé
  INK=E_PALE;for(let i=0;i<300;i++){const a=rnd()*TAU;put(n,[.27*Math.cos(a),-.8-rnd()*.17,.2*Math.sin(a)])}INK=0})();
const OVAIRE=org('Ovaire','Une amande de 3 à 4 cm. Elle abrite depuis la naissance la réserve d\'ovocytes, chacun dans son follicule ; à chaque cycle, quelques follicules grossissent et un seul libère son ovocyte. L\'ovaire fabrique aussi les œstrogènes et la progestérone.',.035);
(()=>{const n=OVAIRE,F=d=>[d[0]*.55,d[1]*.85,d[2]*.45];for(let i=0;i<1100;i++){const d=dir(),w=1+.04*Math.sin(d[0]*9)*Math.sin(d[1]*7+d[2]*8);put(n,mulS(F(d),w))}
  for(let i=0;i<260;i++){const d=dir();put(n,mulS(F(d),.82+.1*rnd()),OVOCYTE,.012)}
  [[.2,.45,.1,.2],[-.22,.05,.15,.15],[.15,-.4,-.12,.12],[-.1,-.55,.1,.09],[.25,0,-.2,.07]].forEach(f=>{for(let i=0;i<340*f[3]/.2;i++)put(n,add(f,mulS(dir(),f[3])));
    put(n,add(f,[f[3]*.55,0,0]),OVOCYTE,Math.min(.05,f[3]*.3));for(let i=0;i<30;i++)put(n,add(f,add([f[3]*.55,0,0],mulS(dir(),f[3]*.36))));for(let i=0;i<8;i++)put(n,add(f,mulS(inBall(),f[3]*.8)),EAU,.004)});
  INK=E_JAUNE;for(let i=0;i<360;i++)put(n,add([-.15,.5,-.12],mulS(inBall(),.16)));INK=0;                                                       // corps jaune
  for(let i=0;i<6;i++)put(n,[rs()*.12,-.3+i*.12,rs()*.1],VAISSEAU,.04,vers([0,1,0]));for(let i=0;i<40;i++)put(n,F(mulS(inBall(),.6)),CAPILLAIRE,.025)})();
const TESTICULE=org('Testicule','L\'usine à spermatozoïdes : plusieurs centaines de mètres de tubes très fins, pelotonnés en lobules, où les cellules germinales se divisent sans arrêt. Il lui faut 2 à 3 °C de moins que le reste du corps, d\'où sa place à l\'extérieur. Entre les tubes se fabrique la testostérone.',.05);
(()=>{const n=TESTICULE,F=d=>[d[0]*.52,d[1]*.74-.05,d[2]*.5];for(let i=0;i<1100;i++)put(n,F(dir()));
  for(let L=0;L<26;L++){let p=F(mulS(inBall(),.75)),d=dir();for(let i=0;i<34;i++){d=norm(add(d,mulS(dir(),.9)));let q=add(p,mulS(d,.045));const u=[q[0]/.5,(q[1]+.05)/.72,q[2]/.48];if(len(u)>.95){d=norm(add(mulS(u,-1),mulS(dir(),.5)));q=add(p,mulS(d,.045))}
      line(n,p,q,3,.008);if(i%2)put(n,q,SPERMATO,.007);p=q}}
  for(let i=0;i<36;i++)put(n,F(mulS(inBall(),.85)),CAPILLAIRE,.025);
  const epi=lisse([[0,.72,-.3],[-.05,.5,-.5],[-.03,0,-.58],[0,-.5,-.5],[.02,-.72,-.32]],5);semer(n,epi,.1,.05,650,undefined,0,{plein:1});semer(n,epi,.07,.03,150,SPERMATO,.007,{plein:1});   // épididyme
  semer(n,lisse([[.02,-.72,-.32],[.05,-.5,-.62],[.05,.3,-.66],[.04,.97,-.6]],5),.022,.022,330);                                              // canal déférent
  for(let i=0;i<4;i++)put(n,[.1,.55+i*.1,-.45],VAISSEAU,.04,vers([0,1,0]))})();
const PROSTATE=org('Prostate','Une glande de la taille d\'une châtaigne, sous la vessie, traversée par l\'urètre. Elle fabrique une partie du liquide séminal, riche en enzymes, qui nourrit et protège les spermatozoïdes. Avec l\'âge elle grossit souvent et peut gêner le passage de l\'urine.',.04);
(()=>{const n=PROSTATE,F=d=>{const k=.55+.3*(d[1]+1)/2;return[d[0]*.75*k/.85,d[1]*.72,d[2]*.6*k/.85-.05]};
  for(let i=0;i<1300;i++)put(n,F(dir()));INK=E_URI;semer(n,[[0,.75,.05],[0,.1,-.05],[0,-.75,.1]],.07,.06,420);INK=0;
  let k=0;while(k<46){const c=F(mulS(inBall(),.8));if(Math.hypot(c[0],c[2])<.14)continue;k++;INK=E_REPRO;for(let i=0;i<22;i++)put(n,add(c,mulS(dir(),.06)));INK=0;for(let i=0;i<4;i++)put(n,add(c,mulS(inBall(),.04)),ENZYME,.006);put(n,add(c,mulS(dir(),.08)),CAPILLAIRE,.025)}
  for(let i=0;i<50;i++){const d=dir();put(n,mulS(F(d),.9),FAISCEAU,.022,vers(perp(d),1))}
  for(const s of[-1,1]){INK=E_REPRO;semer(n,lisse([[s*.55,.95,-.55],[s*.3,.6,-.45],[s*.08,.25,-.2],[s*.03,.05,-.06]],4),.03,.02,160);semer(n,lisse([[s*.75,.98,-.6],[s*.5,.8,-.62],[s*.25,.62,-.5]],4),.09,.07,260);INK=0}})();   // canaux éjaculateurs, vésicules séminales
const FEMUR=org('Fémur','L\'os de la cuisse, le plus long et le plus solide du corps : il supporte jusqu\'à trente fois ton poids. En haut, sa tête sphérique s\'emboîte dans le bassin ; en bas, deux condyles roulent sur le tibia. Sous l\'os compact, un os spongieux en dentelle abrite la moelle où naissent les cellules du sang.',.48);
(()=>{const n=FEMUR,L=loc(FEM.c,FEM.r);femurG((p,ax)=>rnd()<.5?put(n,L(p),OSTEON,.012,vers(ax)):put(n,L(p)),7.5);
  INK=E_OS;for(let i=0;i<300;i++)put(n,L(add(FEM.tete,mulS(inBall(),.024))));for(const x of[.063,.107])for(let i=0;i<170;i++)put(n,L(dansEll([x,-.432,.003],[.019,.022,.03])));INK=0;      // os spongieux
  for(let i=0;i<60;i++)put(n,L(add(FEM.tete,mulS(inBall(),.022))),RBC,.004);for(let i=0;i<24;i++)put(n,L(add(FEM.tete,mulS(inBall(),.022))),LYMPHO,.004);
  const D=lisse(FEM.diaph.map(L),4);INK=E_JAUNE;semer(n,D,.028,.028,360,undefined,0,{plein:1});INK=0;semer(n,D,.02,.02,26,CAPILLAIRE,.014,{axe:'x',plein:1});semer(n,D,.01,.01,5,VAISSEAU,.02,{axe:'y'})})();
const VERTEBRE=org('Vertèbre','Une des 33 pièces de la colonne, ici une lombaire. En avant, le corps, un gros cylindre qui porte le poids ; en arrière, un arc osseux qui protège la moelle et ses racines, hérissé d\'apophyses où s\'attachent muscles et ligaments. Entre deux vertèbres, un disque amortit les chocs.',.09);
(()=>{const n=VERTEBRE,v={y:0,h:.04,type:'L',rb:.022},z0=zR(0),L=loc([0,0,z0-.022],.052);
  vertebre((p,arc)=>rnd()<.5?put(n,L(p),OSTEON,.02):put(n,L(p)),v,62);
  INK=E_OS;for(let i=0;i<420;i++){const a=rnd()*TAU,r=.021*Math.sqrt(rnd());put(n,L([r*Math.cos(a),rs()*.014,z0+r*.8*Math.sin(a)]))}INK=0;
  for(let i=0;i<70;i++){const a=rnd()*TAU,r=.02*Math.sqrt(rnd());put(n,L([r*Math.cos(a),rs()*.013,z0+r*.8*Math.sin(a)]),rnd()<.75?RBC:LYMPHO,.006)}                    // moelle rouge
  INK=E_CART;for(let i=0;i<420;i++){const a=rnd()*TAU,r=.022*(.55+.45*rnd());put(n,L([r*Math.cos(a),-.02-rnd()*.007,z0+r*.8*Math.sin(a)]))}INK=0;                      // disque intervertébral
  for(let i=0;i<40;i++){const a=rnd()*TAU;put(n,L([.02*Math.cos(a),-.0235,z0+.016*Math.sin(a)]),COLLAGENE,.012,vers([-Math.sin(a),0,Math.cos(a)]))}
  for(let i=0;i<8;i++){const a=rnd()*TAU,r=.005*rnd();put(n,L([r*Math.cos(a),rs()*.012,z0-.0266+r*Math.sin(a)]),NERF,.03,0)}})();                                     // racines de la queue de cheval
// paroi d'un gros vaisseau : tunique semée de collagène, lumière faite de tronçons de vaisseau où plonger
function grosVaisseau(n,pts,R0,R1,ph0,enc,dens=1){const T=longueur(pts);INK=enc;semer(n,pts,R0,R1,Math.round(T*460*dens),undefined,0,{ph:ph0});semer(n,pts,R0*1.12,R1*1.12,Math.round(T*130*dens),undefined,0,{ph:ph0});INK=0;
  semer(n,pts,R0*1.06,R1*1.06,Math.round(T*40*dens),COLLAGENE,.012,{axe:'y',ph:ph0});
  const nb=Math.max(2,Math.round(T/((R0+R1)*.8)));for(let i=0;i<nb;i++){const u=(i+.5)/nb*T,o=auLong(pts,u);PH=ph0+u;put(n,o.p,VAISSEAU,(R0+(R1-R0)*u/T)*.82,vers(o.t))}PH=0;return ph0+T}
const AORTE=org('Aorte','La plus grosse artère du corps, large comme un tuyau d\'arrosage. Elle sort du cœur, lance trois branches vers la tête et les bras en dessinant une crosse, puis descend le long de la colonne. Sa paroi élastique se gonfle à chaque battement et restitue l\'élan entre deux : c\'est ton pouls.',.2);
(()=>{const n=AORTE,L=loc(K.aorte.c,K.aorte.r),k=1/K.aorte.r,asc=lisse(CH.aoAsc.map(L),5),de=lisse([CH.aoDesc[0],CH.aoDesc[1],CH.aoDesc[2],[.013,.393,-.03]].map(L),5),R=.0135*k;
  let ph=grosVaisseau(n,asc,R,R*.93,.03,E_PAROI);const phC=ph;ph=grosVaisseau(n,de,R*.93,R*.82,ph,E_PAROI);
  const o=asc[0],t0=norm(sub(asc[1],asc[0]));INK=E_PAROI;for(let i=0;i<500;i++){const d=perp(t0),a=Math.atan2(d[2],d[0]);put(n,add(o,add(mulS(d,R*(1.22+.16*Math.cos(3*a))),mulS(t0,rs()*R*.7))))}   // sinus de Valsalva
  INK=E_DENT;for(let c=0;c<3;c++)for(let i=0;i<70;i++){const a=c*TAU/3+rs()*.95,rr=R*(1-.75*Math.cos((a-c*TAU/3)/.95*Math.PI/2));put(n,add(o,[rr*Math.cos(a),-R*.3*rnd(),rr*Math.sin(a)]))}INK=0;   // valve aortique : trois valvules
  [[[-.1,-.02,.1],[-.24,-.14,.2],[-.3,-.34,.24]],[[.1,-.02,-.02],[.22,-.06,.1],[.26,-.26,.26]]].forEach(c=>grosVaisseau(n,lisse(c.map(q=>add(o,q)),4),.03,.02,.03,E_PAROI));   // artères coronaires
  grosVaisseau(n,lisse(CH.tronc.map(L).slice(0,2).concat([L([-.024,.596,.013])]),4),.0065*k,.006*k,.1,E_PAROI);
  grosVaisseau(n,lisse([CH.carG[0],CH.carG[1],[.025,.596,.011]].map(L),4),.004*k,.004*k,.115,E_PAROI);grosVaisseau(n,lisse([CH.scG[0],CH.scG[1],[.032,.595,-.005]].map(L),4),.005*k,.005*k,.13,E_PAROI);
  for(let i=0;i<9;i++)for(const s of[-1,1]){const q=auLong(de,(i+.7)/9.4*longueur(de));grosVaisseau(n,[add(q.p,[s*R*.4,0,-R*.7]),add(q.p,[s*.2,-.03,-.24])],.016,.012,phC+(i+.7)/9.4*longueur(de),E_PAROI,.5)}})();   // artères intercostales
const VEINECAVE=org('Veine cave','Les deux plus grosses veines du corps. La veine cave supérieure ramène au cœur le sang de la tête et des bras ; l\'inférieure, celui du ventre et des jambes, en traversant le foie et le diaphragme. Toutes deux se jettent dans l\'oreillette droite. Paroi mince, pression faible : le sang y revient sans à-coups.',.28);
(()=>{const n=VEINECAVE,L=loc(K.cave.c,K.cave.r),k=1/K.cave.r,sup=lisse(CH.vcs.map(L),5),inf=lisse(CH.vci.slice(0,5).map(L),5);
  grosVaisseau(n,sup,.011*k,.011*k,.02,E_PAROIV);grosVaisseau(n,inf,.0125*k,.012*k,.02,E_PAROIV);
  INK=E_PALE;for(let i=0;i<700;i++)put(n,L(surEll([-.014,.49,.036],[.02,.027,.02])));INK=0;                                                   // oreillette droite, en filigrane
  const phS=.02+longueur(sup);grosVaisseau(n,lisse([[-.026,.578,.022],[-.03,.59,.016],[-.034,.6,.011]].map(L),3),.007*k,.007*k,phS,E_PAROIV);grosVaisseau(n,lisse([[-.026,.578,.022],[-.008,.588,.028],[.014,.596,.024]].map(L),3),.007*k,.007*k,phS,E_PAROIV);
  grosVaisseau(n,lisse([[-.025,.55,.026],[-.022,.562,.0],[-.016,.552,-.03],[-.014,.5,-.045]].map(L),4),.004*k,.004*k,.06,E_PAROIV);            // crosse de la veine azygos
  [[-.07,.415,.03],[-.055,.42,.0],[-.035,.425,.04]].forEach(e=>grosVaisseau(n,[L([-.023,.405,.01]),L(e)],.005*k,.004*k,.09,E_PAROIV,.6));      // veines hépatiques
  for(const s of[-1,1])grosVaisseau(n,lisse([[-.021,.3,.004],[-.02+s*.03,.298,-.012],[-.02+s*.055,.297,-.028]].map(L),3),.004*k,.004*k,.2,E_PAROIV,.6)})();   // veines rénales

/* ───────── le corps ───────── */
// Les deux corps sont bâtis système par système sur les mêmes plans (gabarit masculin). Le corps féminin s'en déduit par une déformation
// continue du squelette et de tout ce qui s'y accroche (épaules et cage thoracique plus étroites, bassin plus large), une silhouette propre,
// et ses organes reproducteurs.
const DESC_CORPS='Environ 37 000 milliards de cellules, et 7 milliards de milliards de milliards d\'atomes, presque tous nés dans des étoiles. Chaque point s\'ouvre quand tu t\'en approches : choisis un endroit et zoome.';
const sxF=spline([[-.98,1],[-.45,1],[-.25,1.01],[-.05,1.06],[.05,1.07],[.15,1.06],[.25,.97],[.4,.93],[.6,.93],[.66,.96],[.7,1],[.96,1]]);
const c01=v=>Math.max(0,Math.min(1,v));
// le bras suit une loi linéaire en hauteur (il reste droit) ; tronc et jambes suivent le profil sxF
const WF=p=>{const ax=Math.abs(p[0]),y=p[1],xa=.09+.1*c01((y+.08)/.14),m=Math.min(ax,xa),sb=.93+.13*c01((.6-y)/.8),seuil=.16+.055*c01((.33-y)/.06),
    s=sxF(y)+(sb-sxF(y))*(y>-.3?c01((ax-seuil)/.03):0),x=m*s+(ax-m)*(y>-.3&&ax>xa?.94:1);
  const wy=c01(Math.min((y-.08)/.07,(.66-y)/.05)),wx=c01((.2-ax)/.03),cou=1-.13*c01(Math.min((y-.63)/.03,(.77-y)/.03))*c01((.1-ax)/.02);   // cou plus fin
  return[(p[0]<0?-x:x)*cou,y,cou<1?-.012+(p[2]+.012)*cou:-.01+(p[2]+.01)*(1-.06*wy*wx)]};
const RT=.0022,RP=.0015;      // rayon des points-tissus du corps : gros et fins
const DEBUG={};
// côte i (1 à 12) du côté s : du rachis au bout osseux
const yT=i=>.646-(i-.5)*.0258;
const COTE=[null,[.058,.59,.032],[.085,.548,.04],[.105,.517,.048],[.12,.487,.057],[.132,.458,.068],[.14,.428,.082],[.146,.398,.1],[.15,.362,.118],[.15,.325,.13],[.146,.29,.135],[.135,.285,0],[.115,.305,0]];
const zSt=spline([[.2,.07],[.26,.085],[.3,.092],[.41,.098],[.545,.072],[.6,.045],[.62,.035]]);        // plan du sternum et de la paroi antérieure
function cote(i,s){const a=COTE[i][0],yF=COTE[i][1],xF=COTE[i][2],y0=yT(i),zb=zR(y0)-.04,zf=zSt(yF)-.004,zc=(zb+zf)/2,b=(zf-zb)/2;
  const phiF=i===11?1.75:i===12?1.15:Math.PI-Math.asin(Math.min(1,xF/a)),pts=[[s*.02,y0,zR(y0)-.012]];
  for(let k=0;k<=12;k++){const ph=.5+(phiF-.5)*k/12;pts.push([s*a*Math.sin(ph),y0+(yF-y0)*Math.pow(ph/phiF,1.4),zc-b*Math.cos(ph)])}
  return lisse(pts,2)}
const CARTS=[null,[.018,.592],[.018,.545],[.018,.517],[.019,.49],[.02,.465],[.02,.44],[.019,.418],[.07,.392],[.1,.356],[.122,.318]];   // arrivée des cartilages costaux
// main et pied gauches : os longs [départ, arrivée, rayon]
const MAIN=(()=>{const o=[],kn=[[.284,-.092,.058],[.285,-.097,.04],[.284,-.092,.022],[.282,-.083,.006]],ba=[[.277,-.037,.044],[.278,-.038,.034],[.277,-.037,.024],[.276,-.036,.014]],lg=[[.046,.026,.02],[.05,.03,.021],[.046,.028,.021],[.036,.02,.018]];
  kn.forEach((k,i)=>{o.push([ba[i],k,.0038]);let p=k;lg[i].forEach((l,j)=>{const q=add(p,[.002-j*.004,-l,.004-i*.001]);o.push([p,q,.0032-j*.0003]);p=q})});
  o.push([[.275,-.022,.05],[.276,-.058,.076],.0042],[[.276,-.058,.076],[.279,-.09,.09],.0036],[[.279,-.09,.09],[.281,-.115,.098],.0032]);return o})();
const PIED=(()=>{const o=[],xb=[.068,.078,.087,.096,.105],xh=[.06,.075,.089,.102,.114];
  for(let i=0;i<5;i++){const b=[xb[i],-.936-.004*i,.046],h=[xh[i],-.968,.128-.007*i];o.push([b,h,.0042]);let p=h;(i?[.022,.012,.01]:[.03,.024]).forEach(l=>{const q=add(p,[.001*(i-1),-.001,l]);o.push([p,q,i?.003:.0045]);p=q})}return o})();

function corps(F){const B=node('Corps humain',DESC_CORPS,1.75,'Organisme'),W=F?WF:(p=>p),bil=f=>{f(1);f(-1)};
  const kid=(c,p,r,rot,ph)=>{SYS=null;TINT=0;PH=ph||0;put(B,W(p),c,r,rot===undefined?0:rot);PH=0};

  /* ── organes ── */
  kid(CERVEAU,[0,.882,-.005],.108);kid(OEIL,[-.035,.827,.078],.0155);kid(OEIL,[.035,.827,.078],.0155,RZ180);
  kid(HYPOPHYSE,[0,.838,.012],.007);kid(OREILLE,[.048,.832,-.012],.012);kid(OREILLE,[-.048,.832,-.012],.012,RY180);kid(LANGUE,[0,.752,.048],.05,0,.03);
  kid(LARYNX,[0,.675,.028],.026,0,.005);kid(THYROIDE,[0,.643,.03],.028);kid(TRACHEE,K.trachee.c,K.trachee.r,0,.06);kid(OESOPHAGE,K.oeso.c,K.oeso.r,0,.3);
  bil(s=>kid(POUMON,[s*.073,.512,-.012],.118,0,.2));kid(COEUR,[.03,.49,.045],.07,repere([-.42,.86,-.28],[-1,0,0]));kid(AORTE,K.aorte.c,K.aorte.r);kid(VEINECAVE,K.cave.c,K.cave.r);
  kid(THYMUS,[0,.566,.05],.03);kid(DIAPHRAGME,K.dia.c,K.dia.r);kid(FOIE,[-.04,.375,.015],.115);kid(VESBIL,[-.062,.335,.055],.04);kid(ESTOMAC,[.06,.36,.035],.08,0,.5);
  kid(RATE,[.115,.365,-.045],.065);kid(PANCREAS,[.025,.318,.012],.08);kid(REIN,[.062,.3,-.04],.072);kid(REIN,[-.062,.287,-.04],.072,RY180);
  kid(SURRENALE,[.05,.372,-.035],.025);kid(SURRENALE,[-.05,.36,-.035],.025,RY180);kid(INTESTINS,[0,.185,.045],.16,0,.85);kid(VESSIE,[0,.035,.035],.05);
  if(F){kid(UTERUS,[0,.072,.004],.055,repere([0,.77,.64],[1,0,0]));bil(s=>kid(OVAIRE,[s*.052,.094,-.012],.02))}
  else{kid(PROSTATE,[0,-.012,.022],.022);bil(s=>kid(TESTICULE,[s*.022,-.095,.055],.026,s>0?0:RY180))}
  bil(s=>{[[.05,.705,0],[.045,.66,.006],[.165,.545,-.005],[.155,.52,.012],[.075,.035,.066],[.07,0,.062]].forEach(g=>kid(GANGLION,[s*g[0],g[1],g[2]],.0067))});
  [.716,.5,.345].forEach(y=>kid(MOELLE,[0,y,canalZ(y)],.033));
  [[VERT[20],.052],[VERT[22],.052],[VERT[13],.04]].forEach(q=>kid(VERTEBRE,[0,q[0].y,zR(q[0].y)-.022*q[1]/.052],q[1]));
  kid(FEMUR,FEM.c,FEM.r);kid(FEMUR,[-FEM.c[0],FEM.c[1],FEM.c[2]],FEM.r,RY180);

  /* ── squelette (1) ── */
  SYS=1;TINT=E_OS;
  const os=(pts,r0,r1,nb,k=3)=>semer(B,pts.length>2?lisse(pts,k):pts,r0,r1,nb,OSTEON,RT,{W,axe:'y'}),amas=(c,r,nb)=>{for(let i=0;i<nb;i++)put(B,W(surEll(c,r)),OSTEON,RT)};
  const cart=(pts,r,nb)=>{INK=E_CART;semer(B,pts,r,r,nb,undefined,0,{W});INK=0};
  // crâne : voûte, face, orbites, mandibule, dents
  (()=>{const CC=[0,.862,-.005],CR=[.076,.091,.1];let n=0;
    while(n<580){const p=surEll(CC,CR);if((p[1]<.778&&Math.hypot(p[0],p[2]+.036)<.017)||(p[2]>.03&&p[1]<.848))continue;put(B,p,OSTEON,RT);n++}
    n=0;while(n<330){const th=rs()*1.48,y=.752+rnd()*.096,f=y<.785?.8+.2*(y-.752)/.033:1,x=.06*f*Math.sin(th),z=.022+.075*Math.sqrt(f)*Math.cos(th);
      if(((Math.abs(x)-.035)/.0215)**2+((y-.827)/.0185)**2<1||(Math.abs(x)<.011+(.806-y)*.12&&y>.772&&y<.806))continue;put(B,[x,y,z],OSTEON,RT);n++}
    bil(s=>{for(let i=0;i<24;i++){const a=i*TAU/24,x=.035+.0215*Math.cos(a),th=Math.asin(Math.min(1,x/.06));put(B,[s*x,.827+.0185*Math.sin(a),.022+.075*Math.cos(th)],OSTEON,RT)}
      os([[s*.056,.806,.058],[s*.068,.805,.03],[s*.069,.807,.004]],.0035,.0035,13);
      os([[s*.002,.719,.08],[s*.03,.72,.07],[s*.046,.726,.034],[s*.052,.734,.005],[s*.058,.765,-.002],[s*.062,.803,.002]],.008,.006,62);os([[s*.056,.762,.002],[s*.055,.795,.026]],.004,.004,8)});
    INK=E_DENT;for(const yy of[.7535,.7445])for(let i=0;i<30;i++){const th=-1.25+i*2.5/29;put(B,[.034*Math.sin(th),yy+gs()*.0015,.03+.057*Math.cos(th)])}INK=0;
    for(let i=0;i<12;i++){const a=-1.6+i*3.2/11;put(B,[.018*Math.sin(a),.698,.014+.018*Math.cos(a)],OSTEON,RT)}})();     // os hyoïde
  // colonne vertébrale, sacrum, coccyx
  VERT.forEach(v=>vertebre(p=>put(B,W(p),OSTEON,RT),v,1));
  for(let i=0;i<190;i++){const t=rnd(),y=.136-t*.106,w=.058-.044*t,x=rs()*w;if([.115,.092,.07,.05].some(h=>Math.hypot(Math.abs(x)-.024+.01*t,y-h)<.006))continue;put(B,W([x,y,zR(y)+.012*(1-(x/w)**2)-.006]),OSTEON,RT)}
  for(let i=0;i<14;i++){const y=.028-rnd()*.04;put(B,W([gs()*.004,y,zR(y)+gs()*.003]),OSTEON,RT)}
  // côtes, cartilages costaux, sternum
  bil(s=>{for(let i=1;i<=12;i++){const c=cote(i,s),L=longueur(c);os(c,.0045,.0045,Math.round(L*205),1);
      if(i<=10){const e=c[c.length-1],a=CARTS[i],f=[s*a[0],a[1],zSt(a[1])-.002-Math.max(0,a[0]-.03)*.25];cart(lisse([e,lerp(e,f,.5).map((v,q)=>q===1?v-(i>6?.012:0):v),f],3),.0045,Math.round(dist(e,f)*170))}}});
  for(let i=0;i<170;i++){const y=.385+rnd()*.217,w=y>.545?.02+.01*(y-.545)/.057:y>.412?.021-.005*(y-.412)/.133:.008;put(B,W([rs()*w,y,zSt(y)+gs()*.002]),OSTEON,RT)}
  // ceinture scapulaire et membre supérieur
  bil(s=>{const m=p=>[p[0]*s,p[1],p[2]],M=a=>a.map(m);
    os(M([[.02,.603,.047],[.07,.608,.058],[.13,.613,.03],[.185,.618,-.005],[.208,.617,-.012]]),.006,.006,62);                              // clavicule
    const SA=[.075,.612,-.07],IA=[.1,.458,-.094],GL=[.172,.585,-.03];
    for(let i=0;i<120;i++){const a=Math.sqrt(rnd()),b=rnd();put(B,W(m(add(add(mulS(SA,1-a),mulS(IA,a*(1-b))),mulS(GL,a*b)))),OSTEON,RT)}  // omoplate
    os(M([[.08,.585,-.082],[.14,.6,-.068],[.195,.612,-.04],[.215,.613,-.012]]),.005,.006,36);os(M([[.17,.598,-.02],[.172,.6,.012],[.185,.586,.022]]),.004,.004,11);
    amas(m([.195,.585,-.005]),[.024,.024,.024],42);os(M([[.2,.565,-.005],[.218,.45,-.01],[.24,.31,-.018]]),.0125,.0115,125);                // humérus
    os(M([[.24,.31,-.018],[.244,.276,-.02]]),.0115,.019,20);os(M([[.213,.272,-.024],[.245,.262,-.02],[.271,.27,-.016]]),.0085,.0085,30);
    os(M([[.259,.25,-.012],[.266,.14,.01],[.274,.02,.042]]),.0065,.0095,80);os(M([[.236,.276,-.04],[.24,.25,-.03],[.256,.13,0],[.268,.02,.018]]),.0105,.005,80);   // radius, ulna
    for(let r=0;r<2;r++)for(let i=0;i<4;i++)amas(m([.275,-.008-r*.014,.014+i*.0105-r*.002]),[.005,.0065,.005],5);                          // carpe
    MAIN.forEach(o=>os([m(o[0]),m(o[1])],o[2],o[2],Math.max(3,Math.round(dist(o[0],o[1])*170))))});
  // bassin
  bil(s=>{const m=p=>[p[0]*s,p[1],p[2]],M=a=>a.map(m),cr=lisse([[.038,.135,-.082],[.085,.19,-.07],[.135,.2,-.025],[.153,.185,.015],[.128,.105,.058]],5);
    os(M(cr),.006,.006,60,1);
    for(let i=0;i<210;i++){const u=rnd(),v=Math.sqrt(rnd()),c=cr[Math.min(cr.length-1,u*cr.length|0)],b=lerp([.045,.07,-.06],[.105,.058,.03],u),p=lerp(c,b,v);put(B,W(m([p[0]-.012*Math.sin(Math.PI*v),p[1],p[2]])),OSTEON,RT)}
    const H=FEM.tete,nn=norm([.75,-.3,.3]),e1=norm(cross(nn,[0,1,0])),e2=cross(nn,e1);for(let i=0;i<30;i++){const a=i*TAU/30;put(B,W(m(add(H,add(mulS(e1,.03*Math.cos(a)),mulS(e2,.03*Math.sin(a)))))),OSTEON,RT)}
    for(let i=0;i<26;i++){const d=dir();if(dot(d,nn)>-.2)continue;put(B,W(m(add(H,mulS(d,.03)))),OSTEON,RT)}
    os(M([[.085,.046,.034],[.045,.022,.058],[.008,.008,.064]]),.008,.008,36);os(M([[.008,-.018,.058],[.035,-.045,.02],[.062,-.062,-.022],[.085,-.02,-.03],[.092,.03,-.025]]),.009,.009,70)});
  cart([[-.008,-.005,.062],[.008,-.005,.062]],.008,14);
  // membre inférieur
  bil(s=>{const m=p=>[p[0]*s,p[1],p[2]],M=a=>a.map(m);femurG((p,ax)=>put(B,W(m(p)),OSTEON,RT,vers(m(ax))),1);
    amas(m([.085,-.425,.047]),[.021,.023,.01],22);                                                                                         // rotule
    os(M([[.085,-.452,0],[.085,-.5,.005]]),.038,.02,50);os(M([[.085,-.5,.005],[.083,-.7,.006],[.08,-.87,-.006]]),.02,.013,165);os(M([[.08,-.87,-.006],[.08,-.905,-.008]]),.013,.022,26);
    amas(m([.062,-.91,-.008]),[.01,.014,.012],10);os(M([[.124,-.472,-.022],[.12,-.65,-.02],[.11,-.9,-.022]]),.006,.006,74);amas(m([.124,-.47,-.022]),[.01,.012,.01],8);amas(m([.108,-.915,-.022]),[.01,.016,.012],10);
    amas(m([.083,-.922,-.008]),[.02,.017,.022],26);amas(m([.084,-.95,-.04]),[.015,.018,.034],40);amas(m([.075,-.936,.022]),[.013,.012,.012],12);amas(m([.1,-.95,.025]),[.013,.011,.017],12);
    for(let i=0;i<3;i++)amas(m([.068+i*.0105,-.938-.003*i,.038]),[.005,.008,.008],5);
    PIED.forEach(o=>os([m(o[0]),m(o[1])],o[2],o[2],Math.max(3,Math.round(dist(o[0],o[1])*170))))});

  /* ── muscles (2) ── */
  SYS=2;TINT=E_MUSC;const KM=6500;
  const fus=(a,b,r,off,k=1)=>{off=off||[0,0,0];const mm=add(lerp(a,b,.5),mulS(off,2)),nb=Math.ceil(KM*dist(a,b)*r*k);
    for(let i=0;i<nb;i++){const t=(i+rnd())/nb,c=bez(a,mm,b,t),tg=norm(sub(bez(a,mm,b,Math.min(1,t+.03)),bez(a,mm,b,Math.max(0,t-.03)))),rr=r*Math.pow(Math.sin(Math.PI*(.04+.92*t)),.6)*Math.pow(rnd(),.3);
      put(B,W(add(c,mulS(perp(tg),rr))),FAISCEAU,RT,vers(tg,1))}};
  const poly=(P,u)=>{if(P.length===1)return P[0];const x=u*(P.length-1),i=Math.min(P.length-2,x|0);return lerp(P[i],P[i+1],x-i)};
  const nappe=(O,I,bomb,nb,ep=.006)=>{for(let i=0;i<nb;i++){const u=rnd(),t=rnd(),o=poly(O,u),e=poly(I,u),mm=add(lerp(o,e,.5),mulS(bomb,2)),c=bez(o,mm,e,t),tg=sub(bez(o,mm,e,Math.min(1,t+.03)),bez(o,mm,e,Math.max(0,t-.03)));
      put(B,W(add(c,mulS(dir(),ep*Math.sqrt(Math.sin(Math.PI*t))*rnd()))),FAISCEAU,RT,vers(tg,1))}};
  bil(s=>{const m=p=>[p[0]*s,p[1],p[2]],M=a=>a.map(m);
    nappe(M([[.15,.613,.022],[.214,.616,-.012],[.14,.6,-.075]]),[m([.229,.44,-.008])],m([.03,.03,0]),170,.008);                             // deltoïde
    nappe(M([[.03,.598,.052],[.014,.5,.084],[.035,.432,.098]]),M([[.2,.535,.016],[.203,.5,.014]]),[0,0,.012],230,.012);                                          // grand pectoral
    nappe(M([[.012,.776,-.058],[0,.672,-.06],[0,.5,-.108],[0,.35,-.09]]),M([[.14,.615,-.03],[.2,.613,-.03],[.15,.6,-.07],[.1,.585,-.085]]),[0,0,-.006],230,.005);   // trapèze
    nappe(M([[0,.48,-.108],[0,.3,-.068],[0,.13,-.085],[.09,.185,-.072]]),[m([.196,.525,.004])],m([.022,-.02,-.014]),240,.006);               // grand dorsal
    fus(m([.022,.607,.046]),m([.066,.798,-.018]),.009,m([.006,0,.012]),1.6);fus(m([.066,.8,.03]),m([.056,.735,.018]),.009,null,1.5);        // sterno-cléido-mastoïdien, masséter
    fus(m([.188,.572,.022]),m([.251,.246,.002]),.024,m([.004,0,.022]));fus(m([.2,.565,-.03]),m([.238,.272,-.04]),.024,m([.006,0,-.02]));    // biceps, triceps
    fus(m([.215,.272,-.022]),m([.266,.022,.024]),.02,m([-.012,0,-.002]));fus(m([.27,.276,-.016]),m([.281,.022,.036]),.018,m([.012,0,-.008]));fus(m([.256,.32,0]),m([.276,.06,.046]),.012,m([.008,0,.012]));   // avant-bras : fléchisseurs, extenseurs, brachio-radial
    for(let i=0;i<170;i++){const y=.012+rnd()*.42,x=.012+rnd()*.058;if([.19,.262,.334].some(q=>Math.abs(y-q)<.006))continue;put(B,W(m([x,y,zSt(Math.max(.2,y))+(y<.2?-.012*(.2-y)/.19:0)+.006-rnd()*.008-.06*Math.max(0,x-.04)])),FAISCEAU,RT,vers([0,1,0],1))}   // grand droit
    for(let i=0;i<190;i++){const y=.12+rnd()*.29,th=.75+rnd()*1.25,a=.143+.025*Math.abs(y-.27)/.15;put(B,W(m([a*Math.sin(th)**.9,y,-.002+.1*Math.cos(th)])),FAISCEAU,RT,vers(m([-.5,-.7,.5]),1))}   // oblique externe
    {const e=[];for(let y=.1;y<=.66;y+=.04)e.push(m([.03,y,zR(y)-(y>.6?.03:.045)]));SYS=2;semer(B,e,.016,.011,150,FAISCEAU,RT,{W,axe:'x',plein:1})}   // érecteurs du rachis
    nappe(M([[.1,.172,-.068],[.035,.12,-.092],[.016,.03,-.094]]),M([[.165,-.02,-.02],[.14,-.09,-.03]]),m([.01,0,-.05]),250,.012);            // grand fessier
    nappe(M([[.09,.19,-.04],[.15,.182,.008],[.135,.125,.05]]),[m([.178,.045,-.004])],m([.012,0,0]),110,.006);                               // moyen fessier
    fus(m([.026,.3,-.012]),m([.126,-.022,-.006]),.017,m([.012,0,.03]));                                                                      // psoas-iliaque
    fus(m([.12,.08,.045]),m([.085,-.4,.05]),.028,m([0,0,.026]));fus(m([.165,0,.01]),m([.107,-.4,.04]),.03,m([.022,0,.012]));fus(m([.105,-.15,.032]),m([.068,-.412,.04]),.026,m([-.018,0,.01]));   // quadriceps : droit fémoral, vaste latéral, vaste médial
    fus(m([.075,-.055,-.03]),m([.122,-.468,-.025]),.024,m([.004,0,-.026]));fus(m([.068,-.055,-.03]),m([.06,-.468,-.01]),.022,m([-.002,0,-.03]));   // ischio-jambiers
    fus(m([.03,-.02,.03]),m([.085,-.33,0]),.03,m([-.022,0,0]));                                                                              // adducteurs
    semer(B,lisse(M([[.13,.095,.06],[.105,-.05,.075],[.06,-.3,.05],[.045,-.43,0],[.064,-.48,.02]]),4),.008,.006,70,FAISCEAU,RT,{W,axe:'x',plein:1});   // sartorius
    fus(m([.07,-.43,-.03]),m([.083,-.72,-.045]),.027,m([-.012,0,-.03]));fus(m([.1,-.43,-.03]),m([.085,-.7,-.045]),.024,m([.012,0,-.028]));fus(m([.09,-.5,-.028]),m([.083,-.8,-.036]),.018,m([0,0,-.002]));   // triceps sural : gastrocnémiens, soléaire
    fus(m([.105,-.47,.015]),m([.075,-.88,.015]),.016,m([.008,0,.012]));fus(m([.125,-.5,-.015]),m([.11,-.88,-.03]),.011);                    // tibial antérieur, fibulaires
    INK=E_TEND;SYS=2;semer(B,M([[.083,-.72,-.042],[.083,-.94,-.064]]),.008,.006,60,undefined,0,{W,plein:1});                                // tendon d'Achille
    semer(B,M([[.085,-.4,.052],[.085,-.47,.03]]),.009,.008,24,undefined,0,{W,plein:1});INK=0;                                              // tendon rotulien
    const mk=(a,b,off,r)=>{const c=add(lerp(a,b,.5),off);SYS=null;TINT=0;put(B,W(c),MUSCLE,r,repere(sub(a,b),[1,0,0]));SYS=2;TINT=E_MUSC};
    mk(m([.188,.572,.022]),m([.251,.246,.002]),m([.004,0,.022]),.15);mk(m([.12,.08,.045]),m([.085,-.4,.05]),m([0,0,.026]),.16)});

  /* ── cœur et artères (3) ── */
  const vais=(sy,te)=>(pts,r0,r1,ph,k=3)=>{SYS=sy;TINT=te;const P=lisse(pts,k),rm=(r0+r1)/2;return semer(B,P,r0,r1,Math.ceil(longueur(P)*(140+39000*rm)),VAISSEAU,rm>.0032?RT:RP,{W,axe:'y',ph,plein:rm<.004})};
  const A=vais(3,E_ART),V=vais(4,E_VEIN),AP=vais(3,E_VEIN),VP=vais(4,E_ART),mx=(pts,s)=>pts.map(p=>[p[0]*s,p[1],p[2]]);
  (()=>{let ph=A(CH.aoAsc,.0135,.0125,.02,4);const phC=ph;A(CH.aoDesc,.012,.0085,ph,4);
    const pt=A(CH.tronc,.0065,.006,.08),pc=A(CH.carG,.004,.004,.095),ps=A(CH.scG,.005,.005,.11);
    bil(s=>{const m=a=>mx(a,s),p0=s>0?pc:pt,p1=s>0?ps:pt;
      let p=A(m([[.03,.607,.011],[.034,.66,.016],[.036,.725,.012]]),.0038,.0036,p0);                                                         // carotide commune
      A(m([[.036,.725,.012],[.036,.77,-.002],[.03,.8,0],[.018,.835,.012],[.02,.86,.03]]),.0028,.002,p);                                      // carotide interne
      const pe=A(m([[.036,.725,.012],[.048,.76,.02],[.062,.79,.012],[.072,.85,.01],[.068,.9,.02]]),.0022,.001,p);A(m([[.048,.76,.02],[.05,.745,.055],[.03,.775,.085]]),.0012,.001,p+.04);   // carotide externe, faciale
      p=A(m([[s>0?.04:.028,s>0?.612:.603,s>0?-.003:.01],[.075,.622,.004],[.11,.61,.008],[.15,.582,.004]]),.0048,.004,p1);                   // sous-clavière
      A(m([[.05,.618,-.002],[.024,.64,-.03],[.022,.72,-.022],[.03,.775,-.03],[.008,.795,-.03],[0,.815,-.015]]),.0018,.0015,p1+.02);          // vertébrale
      p=A(m([[.15,.582,.004],[.178,.54,0],[.2,.45,-.004],[.228,.33,0],[.243,.262,.006]]),.004,.0026,p);                                      // axillaire, brachiale
      const pr=A(m([[.243,.262,.006],[.256,.21,.014],[.266,.12,.034],[.27,.01,.046],[.276,-.03,.062]]),.0016,.0012,p),                      // radiale
        pu=A(m([[.243,.262,.006],[.244,.21,0],[.252,.12,.004],[.264,.01,.014],[.272,-.035,.02]]),.0016,.0012,p);                            // ulnaire
      A(m([[.272,-.035,.02],[.277,-.062,.04],[.276,-.03,.062]]),.001,.001,pu);[0,4,8,12].forEach((j,i)=>A(m([[.277,-.062,.05-i*.012],MAIN[j][1],MAIN[j+3][1]]),.0008,.0008,pu+.03,2));   // arcade palmaire, artères des doigts
      const o=surY(AOD,.303);A([o.p,[s*.03,.3,-.01],[s*.05,.298,-.03]],.003,.0028,phC+o.s);                 // rénale
      const E=CH.aoDesc[5],pb=phC+longueur(AOD);p=A([E,[s*.025,.165,.012],[s*.042,.125,.008]],.0058,.0052,pb);                              // iliaque commune
      const pi=A(m([[.042,.125,.008],[.035,.08,-.025],[.04,.04,-.04],[.06,0,-.05]]),.004,.002,p);A(m([[.035,.08,-.025],[.015,.04,.01]]),.0015,.0012,p+.05);   // iliaque interne
      p=A(m([[.042,.125,.008],[.07,.085,.03],[.072,.045,.058]]),.005,.0048,p);                                                               // iliaque externe
      A(m([[.076,0,.055],[.1,-.06,.025],[.11,-.2,0],[.1,-.33,-.012]]),.0035,.0018,p+.045);                                                  // fémorale profonde
      p=A(m([[.072,.045,.058],[.076,-.05,.055],[.07,-.2,.035],[.068,-.33,.004],[.082,-.42,-.028]]),.0046,.0036,p);                           // fémorale
      p=A(m([[.082,-.42,-.028],[.086,-.46,-.03],[.088,-.5,-.026]]),.0034,.003,p);                                                            // poplitée
      A(m([[.088,-.5,-.026],[.1,-.53,-.008],[.098,-.6,.012],[.088,-.8,.016],[.082,-.9,.018],[.082,-.945,.06],[.08,-.958,.11]]),.0018,.0012,p);   // tibiale antérieure, pédieuse
      A(m([[.088,-.5,-.026],[.082,-.6,-.022],[.072,-.8,-.02],[.062,-.915,-.03],[.075,-.968,.02],[.09,-.972,.1]]),.002,.0012,p);              // tibiale postérieure, plantaire
      A(m([[.086,-.53,-.025],[.105,-.62,-.028],[.108,-.85,-.03]]),.0015,.0012,p+.03)});                                                      // fibulaire
    let o=surY(AOD,.345),q=o.p,p=A([q,add(q,[0,-.004,.022])],.0035,.0035,phC+o.s);q=add(q,[0,-.004,.022]);                                  // tronc cœliaque
    A([q,[-.03,.352,.032],[-.055,.37,.03]],.0025,.002,p);A([q,[.04,.345,.014],[.08,.352,-.01],[.105,.362,-.03]],.0025,.002,p);A([q,[.03,.37,.036],[.05,.386,.046]],.0015,.0012,p);   // hépatique, splénique, gastrique gauche
    o=surY(AOD,.325);p=A([o.p,[.004,.3,.03],[0,.24,.05],[-.01,.17,.05]],.0035,.002,phC+o.s);                                                // mésentérique supérieure
    [[[0,.26,.045],[.05,.22,.05]],[[0,.22,.05],[-.06,.2,.045]],[[-.005,.2,.05],[.04,.14,.05]]].forEach(b=>A(b,.0013,.001,p-.06));
    o=surY(AOD,.235);A([o.p,[.02,.2,.03],[.04,.13,.03],[.03,.08,.01]],.002,.0014,phC+o.s);                                                  // mésentérique inférieure
    // petite circulation : les artères pulmonaires portent un sang pauvre en oxygène (bleu), les veines pulmonaires un sang riche (rouge)
    p=AP([[.022,.515,.068],[.02,.54,.05],[.014,.552,.02],[.01,.548,.002]],.0125,.0115,.02);AP([[.01,.548,.002],[-.02,.54,0],[-.05,.522,-.008]],.009,.007,p);AP([[.01,.548,.002],[.035,.54,-.012],[.052,.525,-.016]],.008,.007,p)})();

  /* ── veines (4) : la phase est la distance qui reste jusqu'au cœur ── */
  (()=>{let ph=V(CH.vcs,.011,.011,.02,4);
    bil(s=>{const m=a=>mx(a,s);let p=V(s>0?[[-.026,.578,.022],[0,.59,.03],[.035,.605,.012]]:[[-.026,.578,.022],[-.03,.592,.016],[-.035,.605,.01]],.007,.0065,ph);   // tronc veineux brachio-céphalique
      V(m([[.035,.605,.011],[.042,.66,.012],[.042,.725,.008],[.04,.79,-.015],[.05,.815,-.05]]),.006,.0045,p);                                // jugulaire interne
      V(m([[.05,.612,.006],[.052,.68,-.004],[.054,.74,0]]),.0018,.0014,p+.01);                                                               // jugulaire externe
      p=V(m([[.035,.605,.011],[.075,.612,.012],[.115,.6,.014],[.15,.574,.01]]),.006,.005,p);                                                 // sous-clavière
      const pa=V(m([[.15,.574,.01],[.176,.535,-.006],[.196,.45,-.01],[.224,.33,-.008],[.24,.262,0]]),.0045,.003,p);                          // axillaire, brachiale
      V(m([[.165,.58,.03],[.2,.54,.034],[.234,.45,.018],[.254,.33,.012],[.266,.262,.01],[.274,.14,.026],[.282,.01,.044],[.288,-.04,.06]]),.0018,.0013,p+.01);   // céphalique
      const pb=V(m([[.24,.262,0],[.226,.25,-.014],[.242,.14,0],[.26,.02,.012],[.27,-.04,.016]]),.0018,.0013,pa);V(m([[.226,.262,-.01],[.25,.25,.014],[.268,.262,.012]]),.0013,.0013,pa);   // basilique, médiane du coude
      V(m([[.27,-.04,.014],[.286,-.06,.036],[.288,-.04,.06]]),.001,.001,pb)});
    V([[-.024,.548,.026],[-.022,.562,0],[-.016,.552,-.03],[-.014,.48,-.046],[-.012,.36,-.036]],.004,.003,ph-.03);                            // azygos
    const phI=.02,vc=V(CH.vci,.0125,.011,phI,4);
    [[-.07,.415,.03],[-.055,.42,0],[-.035,.425,.04]].forEach(e=>V([[-.023,.405,.01],e],.004,.003,phI+.07));                                 // veines hépatiques
    let o=surY(VCI,.297);V([o.p,[-.04,.296,-.01],[-.052,.295,-.028]],.004,.0035,phI+o.s);V([o.p,[.006,.3,.016],[.03,.299,-.004],[.052,.297,-.028]],.004,.0035,phI+o.s);   // rénales (la gauche croise devant l'aorte)
    bil(s=>{const m=a=>mx(a,s);let p=V([CH.vci[6],[s*.022-.004,.15,.004],[s*.04,.118,-.002]],.0075,.007,vc);                                 // iliaque commune
      V(m([[.04,.118,-.002],[.03,.075,-.03],[.036,.04,-.045]]),.004,.0025,p);p=V(m([[.04,.118,-.002],[.062,.085,.02],[.064,.045,.05]]),.006,.0055,p);   // iliaques interne et externe
      const pf=p;p=V(m([[.064,.045,.05],[.066,-.05,.046],[.062,-.2,.026],[.066,-.33,-.004],[.086,-.42,-.036]]),.0055,.004,p);                // fémorale
      p=V(m([[.086,-.42,-.036],[.09,-.46,-.038],[.09,-.5,-.034]]),.004,.0035,p);                                                             // poplitée
      V(m([[.09,-.5,-.034],[.086,-.6,-.03],[.078,-.8,-.027],[.067,-.91,-.036],[.08,-.966,.02]]),.0022,.0014,p);                              // tibiales postérieures
      V(m([[.09,-.5,-.034],[.104,-.56,-.004],[.094,-.8,.008],[.088,-.9,.01]]),.0016,.0012,p);                                                // tibiales antérieures
      V(m([[.07,.02,.064],[.05,-.2,.04],[.04,-.38,.006],[.04,-.45,-.02],[.05,-.6,-.004],[.058,-.8,.004],[.062,-.9,.012],[.07,-.95,.06],[.085,-.962,.11]]),.0022,.0013,pf+.03);   // grande saphène
      V(m([[.09,-.46,-.046],[.088,-.6,-.064],[.09,-.8,-.042],[.1,-.92,-.04]]),.0015,.0012,p-.02)});                                          // petite saphène
    // veine porte : le sang de l'intestin et de la rate gagne le foie avant de rejoindre le cœur
    let p=V([[-.04,.366,.022],[-.022,.34,.022],[-.008,.316,.022]],.006,.006,.12);V([[-.04,.366,.022],[-.07,.385,.03]],.004,.003,.1);V([[-.04,.366,.022],[-.03,.4,.012]],.004,.003,.1);
    V([[-.008,.316,.022],[.002,.26,.045],[-.006,.18,.05]],.005,.003,p);V([[-.008,.316,.022],[.04,.33,.008],[.08,.345,-.014],[.104,.358,-.034]],.004,.003,p);V([[.02,.325,.015],[.03,.26,.03],[.04,.14,.034]],.002,.0015,p+.03);
    bil(s=>{for(const dy of[.012,-.016])VP([[.012,.498+dy*.4,-.002],[s*.03,.502+dy,-.01],[s*.052,.506+dy*1.3,-.018]],.006,.005,.02)})})();   // veines pulmonaires

  /* ── système nerveux (5) : la phase est la distance depuis le cerveau ── */
  (()=>{const N=(pts,r,ph,k=3,d=1)=>{SYS=5;TINT=E_NERF;const P=lisse(pts,k);return semer(B,P,r,r,Math.ceil(longueur(P)*(125+15000*r)*d),NERF,r>.0035?RT:RP,{W,axe:'y',ph,plein:1})},phM=y=>.1+(.785-y)*1.03;
    const mo=[];for(let y=.785;y>=.324;y-=.02)mo.push([0,y,canalZ(y)]);SYS=5;TINT=E_NERF;semer(B,mo,.0045,.004,340,SBLANCHE,RT,{W,axe:'x',ph:.1,plein:1});   // moelle épinière, jusqu'au cône terminal (L1-L2)
    bil(s=>{const m=a=>mx(a,s);
      [.19,.15,.115,.092,.07].forEach((y,i)=>N(m([[.003,.325,canalZ(.325)],[.006,.25,canalZ(.25)],[.012,y+.03,canalZ(Math.max(.14,y+.03))],[.024,y,zR(y)-.004]]),.001,phM(.325),3,.6));   // queue de cheval
      N(m([[.03,.855,-.03],[.012,.85,-.005],[.004,.845,.02],[.022,.836,.04],[.035,.827,.066]]),.0022,.03);                                   // nerf optique, chiasma
      let p=N(m([[.01,.795,-.03],[.035,.79,-.015],[.038,.7,.012],[.03,.6,0],[.02,.52,-.026],[.012,.45,-.022],[.016,.395,0]]),.0018,.1);   // nerf vague
      s>0?N([[.016,.395,0],[.045,.37,.04],[.07,.35,.05]],.0012,p):N([[-.016,.395,0],[-.004,.36,.01],[0,.335,.022]],.0012,p);
      if(s>0)N([[.026,.568,-.012],[.02,.552,-.014],[.012,.57,-.006],[.012,.62,.004],[.014,.668,.012]],.001,.34,4);                           // nerf laryngé récurrent gauche, sous la crosse de l'aorte
      N(m([[.018,.736,canalZ(.736)+.004],[.03,.66,.006],[.03,.58,.03],[s>0?.07:.045,.5,.04],[s>0?.06:.04,.428,.035]]),.0012,phM(.736));       // nerf phrénique
      let pp=0;[.716,.696,.676,.656,.633].forEach((y,i)=>{pp=N(m([[.016,y,canalZ(y)+.004],[.05,y-.03-.004*i,-.004],[.09,.612,0]]),.002,phM(y))});   // plexus brachial : racines C5 à T1
      p=N(m([[.09,.612,0],[.12,.6,.004],[.15,.58,.002]]),.0045,pp);
      let q=N(m([[.15,.58,.002],[.18,.535,.004],[.203,.45,0],[.23,.33,.004],[.24,.262,.012],[.257,.14,.022],[.268,.01,.032],[.277,-.04,.045]]),.0024,p);[0,4,16].forEach(j=>N(m([[.277,-.04,.045],MAIN[j===16?17:j][1],MAIN[j===16?18:j+3][1]]),.0008,q,2));   // nerf médian
      q=N(m([[.15,.58,.002],[.175,.53,-.006],[.195,.45,-.012],[.212,.33,-.024],[.214,.262,-.034],[.235,.2,-.02],[.252,.12,0],[.264,.01,.012],[.276,-.04,.016]]),.0022,p);[8,12].forEach(j=>N(m([[.276,-.04,.016],MAIN[j][1],MAIN[j+3][1]]),.0008,q,2));   // nerf ulnaire
      N(m([[.15,.58,.002],[.185,.53,-.022],[.215,.45,-.036],[.248,.37,-.03],[.266,.3,-.008],[.262,.255,.004],[.268,.14,.03],[.279,.01,.048],[.292,-.04,.06]]),.0022,p);   // nerf radial
      N(m([[.15,.58,.002],[.185,.56,-.03],[.23,.54,-.02]]),.0014,p);N(m([[.15,.58,.002],[.2,.5,.012],[.225,.38,.018]]),.0014,p);             // nerfs axillaire et musculo-cutané
      for(let i=1;i<=11;i++){const c=cote(i,s).map(v=>[v[0]*.97,v[1]-.007,v[2]*.97-.001]);SYS=5;TINT=E_NERF;semer(B,c,.0008,.0008,Math.ceil(longueur(c)*70),NERF,RP,{W,axe:'y',ph:phM(yT(i)),plein:1})}   // nerfs intercostaux
      pp=0;[.3,.262,.222].forEach(y=>{pp=N(m([[.02,y,canalZ(y)+.006],[.045,y-.06,.0],[.07,.1,.03]]),.0016,phM(y))});                         // plexus lombaire
      p=N(m([[.07,.1,.03],[.088,.05,.056],[.094,-.06,.054]]),.003,pp);N(m([[.094,-.06,.054],[.11,-.16,.05]]),.0014,p);N(m([[.094,-.06,.054],[.09,-.2,.058]]),.0014,p);   // nerf fémoral
      N(m([[.094,-.06,.054],[.07,-.3,.022],[.05,-.45,-.004],[.054,-.7,.004],[.06,-.9,.006]]),.001,p,3,.8);                                   // nerf saphène
      N(m([[.045,.16,.01],[.04,.06,.012],[.045,0,.022],[.05,-.15,.012]]),.0014,phM(.24));                                                    // nerf obturateur
      pp=0;[.19,.15,.115,.092,.07].forEach(y=>{pp=N(m([[.024,y,zR(y)-.004],[.045,y-.03,-.045],[.066,.04,-.056]]),.002,phM(.325)+(.325-y))});   // plexus sacré
      p=N(m([[.066,.04,-.056],[.09,-.06,-.042],[.09,-.25,-.03],[.088,-.38,-.03]]),.0055,pp);                                                 // nerf sciatique
      q=N(m([[.088,-.38,-.03],[.085,-.44,-.036],[.083,-.65,-.03],[.062,-.91,-.036],[.078,-.97,.02],[.088,-.973,.09]]),.0026,p);              // nerf tibial
      N(m([[.088,-.38,-.03],[.114,-.44,-.03],[.128,-.486,-.012],[.104,-.6,.01],[.09,-.88,.022],[.086,-.948,.08]]),.002,p)})})();             // nerf fibulaire commun

  /* ── conduits des autres systèmes (points sans enfant) ── */
  const trait=(sy,enc,pts,r,nb,ph,k=3)=>{SYS=sy;INK=enc;const e=semer(B,pts.length>2?lisse(pts,k):pts,r,r,nb,undefined,0,{W,ph});INK=0;return e};
  trait(6,E_AIR,[[0,.8,.105],[0,.795,.04],[0,.76,.004],[0,.7,.006]],.008,40);                                                                // fosses nasales, pharynx
  let pa=trait(6,E_AIR,[[0,.7,.012],[0,.675,.022]].concat(CH.trachee),.0105,150,.002);trait(6,E_AIR,CH.broncheD,.0078,45,pa);trait(6,E_AIR,CH.broncheG,.007,55,pa);
  pa=trait(7,E_DIG,[[0,.755,.095],[0,.75,.03],[0,.72,-.004],[0,.655,-.008]],.009,60,.01);trait(7,E_DIG,CH.oeso,.0085,150,pa,4);
  trait(7,E_DIG,[[.012,.315,.06],[-.04,.325,.04],[-.052,.285,.022],[-.02,.262,.016],[.022,.29,.022]],.012,90,.75);trait(7,E_DIG,[[0,.07,-.035],[0,-.01,-.046],[0,-.066,-.036]],.014,70,7.6);   // duodénum, rectum
  bil(s=>trait(8,E_URI,[[s*.04,.292,-.034],[s*.036,.2,-.018],[s*.042,.12,-.03],[s*.026,.058,0],[s*.012,.048,.016]],.0028,70));              // uretères
  if(F){trait(8,E_URI,[[0,-.004,.034],[0,-.056,.034]],.0035,14);trait(11,E_REPRO,[[0,.03,-.006],[0,-.02,.004],[0,-.058,.012]],.011,90)}     // urètre, vagin
  else{trait(8,E_URI,[[0,.005,.03],[0,-.03,.03],[0,-.058,.08],[0,-.125,.098]],.0035,45);
    bil(s=>trait(11,E_REPRO,[[s*.022,-.08,.046],[s*.03,.01,.07],[s*.075,.05,.06],[s*.062,.07,.02],[s*.016,.03,-.004],[s*.004,-.004,.014]],.002,90,undefined,4))}   // canal déférent
  // lymphatiques (10) : canal thoracique et grands collecteurs des membres vers les ganglions
  trait(10,E_LYMPH,[[.002,.31,-.008],[-.002,.4,-.03],[.002,.5,-.04],[.012,.57,-.02],[.036,.606,.01]],.0018,110);
  bil(s=>{trait(10,E_LYMPH,mx([[.08,-.955,.08],[.058,-.8,.01],[.046,-.45,-.012],[.056,-.2,.045],[.072,0,.064],[.07,.06,.04],[.02,.2,.01],[.004,.31,-.006]],s),.0012,120,undefined,4);
    trait(10,E_LYMPH,mx([[.278,-.05,.03],[.26,.14,.006],[.232,.3,-.012],[.2,.45,-.014],[.163,.545,-.004],[.11,.6,.012],[.045,.61,.012]],s),.0012,80,undefined,4);
    trait(10,E_LYMPH,mx([[.05,.76,.01],[.05,.705,0],[.045,.66,.006],[.04,.612,.012]],s),.0012,26)});
  // diaphragme (6) : la coupole, en points fins
  SYS=6;TINT=E_MUSC;for(let i=0;i<230;i++){const x=rs()*.142,z=rs()*.092,rho=diaRho(x,z);if(rho>1)continue;if(rho<.45){INK=E_TEND;put(B,W([x,diaY(x,z),z]));INK=0}else put(B,W([x,diaY(x,z),z]),FAISCEAU,RT,vers([x,0,z],1))}

  /* ── peau (0) : une coque fine sur la silhouette ── */
  SYS=0;TINT=E_PEAU;
  (()=>{const pr=[],ex=2.4,fa=F?.9:1,ft=F?1.04:1,fc=F?.96:1;
    const cap=(a,b,ra,rb)=>{a=W(a);b=W(b);pr.push({a,b,ra,rb,ax:norm(sub(b,a)),L:dist(a,b),A:TAU*(ra+rb)/2*dist(a,b)+TAU*(ra*ra+rb*rb)*.5})};
    const ell=(c,r)=>pr.push({c:W(c),r,A:4*Math.PI*Math.pow((Math.pow(r[0]*r[1],1.6)+Math.pow(r[0]*r[2],1.6)+Math.pow(r[1]*r[2],1.6))/3,1/1.6)});
    const ta=spline(F?[[-.075,.04],[-.05,.12],[-.02,.18],[.05,.205],[.12,.192],[.2,.166],[.27,.152],[.36,.157],[.45,.168],[.52,.174],[.57,.17],[.61,.148],[.65,.082],[.68,.055]]
                     :[[-.075,.04],[-.05,.11],[-.02,.165],[.05,.188],[.12,.178],[.2,.166],[.27,.16],[.36,.166],[.45,.182],[.52,.19],[.57,.186],[.61,.16],[.65,.09],[.68,.064]]),
      tb=spline(F?[[-.075,.05],[0,.105],[.1,.108],[.25,.098],[.4,.108],[.5,.114],[.58,.1],[.63,.072],[.68,.052]]:[[-.075,.05],[0,.105],[.1,.108],[.25,.102],[.4,.118],[.5,.126],[.58,.11],[.63,.08],[.68,.06]]),
      tc=spline([[-.075,-.01],[0,-.015],[.1,-.008],[.25,0],[.4,-.002],[.5,0],[.58,-.01],[.63,-.02],[.68,-.015]]);
    pr.push({tr:1,A:.74});
    bil(s=>{ell([s*.2,.58,-.005],[.058*fa,.07,.06*fa]);cap([s*.045,.672,-.03],[s*.168,.628,-.02],.036,.03);cap([s*.2,.57,-.005],[s*.245,.262,-.02],.05*fa,.04*fa);
      ell([s*.245,.262,-.02],[.044*fa,.05,.046*fa]);cap([s*.245,.262,-.02],[s*.272,.005,.03],.044*fa,.028*fa);ell([s*.279,-.05,.04],[.017,.055,.043]);
      [0,4,8,12].forEach(j=>cap([s*MAIN[j][1][0],MAIN[j][1][1]+.012,MAIN[j][1][2]],[s*MAIN[j+3][1][0],MAIN[j+3][1][1],MAIN[j+3][1][2]],.0095,.0075));cap([s*.275,-.022,.05],[s*.281,-.115,.098],.012,.009);
      cap([s*.098,0,-.008],[s*.086,-.42,.004],.098*ft,.064);ell([s*.085,-.44,.012],[.06,.06,.062]);cap([s*.085,-.46,0],[s*.082,-.89,-.022],.055*fc,.041);ell([s*.085,-.6,-.03],[.055*fc,.12,.05*fc]);
      ell([s*.082,-.945,-.04],[.034,.036,.046]);ell([s*.083,-.925,.015],[.036,.045,.055]);cap([s*.03,.6,.035],[s*.19,.612,0],.028,.028);cap([s*.083,-.946,-.005],[s*.092,-.962,.16],.04,.023);ell([s*.088,-.961,.125],[.05,.021,.088]);
      ell([s*.075,.025,-.052],[.088*(F?1.08:1),.1,.085*(F?1.06:1)]);ell([s*.115,.555,-.05],[.085,.095,.06]);F?ell([s*.08,.478,.1],[.062,.06,.055]):ell([s*.075,.5,.085],[.075,.055,.04]);ell([s*.086,.83,-.005],[.008,.03,.016])});
    cap([0,.62,-.02],[0,.74,-.008],F?.052:.062,F?.049:.058);ell([0,.86,-.005],[.083,.1,.108]);ell([0,.78,.03],[.08,.085,.09]);ell([0,.805,.118],[.014,.026,.02]);
    if(!F){ell([0,-.095,.055],[.036,.036,.032]);cap([0,-.055,.085],[0,-.125,.1],.017,.016)}
    const dans=(p,sauf,k=1)=>pr.some(q=>{if(q===sauf)return false;
      if(q.tr)return p[1]>-.075&&p[1]<.68&&Math.pow(Math.abs(p[0])/ta(p[1]),ex)+Math.pow(Math.abs(p[2]-tc(p[1]))/tb(p[1]),ex)<k;
      if(q.c)return((p[0]-q.c[0])/q.r[0])**2+((p[1]-q.c[1])/q.r[1])**2+((p[2]-q.c[2])/q.r[2])**2<k;
      const t=Math.max(0,Math.min(1,dot(sub(p,q.a),q.ax)/q.L));return dist(p,add(q.a,mulS(q.ax,t*q.L)))<(q.ra+(q.rb-q.ra)*t)*Math.sqrt(k)});
    const tot=pr.reduce((a,q)=>a+q.A,0),sg=(v,e)=>Math.sign(v)*Math.pow(Math.abs(v),e);
    let n=0;for(let it=0;it<60000&&n<(F?3250:3300);it++){let u=rnd()*tot,k=0;while(k<pr.length-1&&u>pr[k].A){u-=pr[k].A;k++}const q=pr[k];let p,nr;
      if(q.tr){const y=-.075+rnd()*.755,a=ta(y),b=tb(y);if(rnd()>(a+b)/.33)continue;const th=rnd()*TAU;p=[a*sg(Math.sin(th),2/ex),y,tc(y)+b*sg(Math.cos(th),2/ex)];nr=[p[0]/(a*a),0,(p[2]-tc(y))/(b*b)]}
      else if(q.c){const d=dir();p=[q.c[0]+d[0]*q.r[0],q.c[1]+d[1]*q.r[1],q.c[2]+d[2]*q.r[2]];nr=[d[0]/q.r[0],d[1]/q.r[1],d[2]/q.r[2]]}
      else{const cA=TAU*(q.ra*q.ra+q.rb*q.rb)*.5;if(rnd()*q.A<cA){const fin=rnd()*(q.ra*q.ra+q.rb*q.rb)>q.ra*q.ra,d=dir();if(dot(d,q.ax)*(fin?1:-1)<0)continue;nr=d;p=add(fin?q.b:q.a,mulS(d,fin?q.rb:q.ra))}
        else{const t=rnd();nr=perp(q.ax);p=add(add(q.a,mulS(q.ax,t*q.L)),mulS(nr,q.ra+(q.rb-q.ra)*t))}}
      if(dans(p,q,.97))continue;if(p[1]<-.98)p[1]=-.98;put(B,p,EPIDERME,RT,vers(nr));n++}
    DEBUG[F?'femme':'homme']=p=>dans(p,null,1)})();
  SYS=null;TINT=0;INK=0;PH=0;return B}
const CORPS=corps(false),CORPS_F=corps(true);

const CATCOL={'Protéine':'#ffb07a','Acide aminé':'#ffc59a','Cellule':'#ffe9c0','Noyau atomique':'#ffcf9a','Organe':'#ffffff','Tissu':'#e8e8e8'};
[[CORPS,'#f4f1ea'],[CORPS_F,'#f4f1ea'],[NERF,'#fff2a8'],[INSULINE,'#ffd24d'],[ILOT,'#ffcf70'],[FOLLICULE,'#ff9f6b'],[CILIEE,'#7ef0e0'],[PAPILLE,'#ff8fa0'],[OVOCYTE,'#ffd0e6'],[SPERMATO,'#e6f0ff'],
 [MUSCLE,'#ff6f61'],[MOELLE,'#ffe9a0'],[TRACHEE,'#a8dcff'],[LARYNX,'#b8e0ff'],[OESOPHAGE,'#ffb070'],[DIAPHRAGME,'#ff7d70'],[PANCREAS,'#ffd070'],[RATE,'#c0405a'],[VESBIL,'#9ad84a'],[VESSIE,'#d0a0ff'],
 [THYROIDE,'#ff8a5a'],[SURRENALE,'#ffcf4d'],[THYMUS,'#c8f0c0'],[GANGLION,'#9dffb0'],[HYPOPHYSE,'#ffb0f0'],[LANGUE,'#ff7f90'],[OREILLE,'#7ef0e0'],[UTERUS,'#ff8fc0'],[OVAIRE,'#ffc0e0'],[TESTICULE,'#c0d0ff'],
 [PROSTATE,'#d0b0ff'],[FEMUR,'#f2ead0'],[VERTEBRE,'#f2ead0'],[AORTE,'#ff3b3b'],[VEINECAVE,'#4d7dff'],[CERVEAU,'#ff9ec4'],[COEUR,'#ff4d5e'],[POUMON,'#7cc8ff'],[FOIE,'#d98a4e'],[ESTOMAC,'#ffb347'],[REIN,'#c58cff'],[INTESTINS,'#ffd97a'],[OEIL,'#5ff0e0'],
 [FAISCEAU,'#ff6f61'],[OSTEON,'#f2ead0'],[EPIDERME,'#ffc9a3'],[VAISSEAU,'#ff3b3b'],[CAPILLAIRE,'#ff5a5a'],[CORTEX,'#ff9ec4'],[CORTEXCB,'#ffa8e6'],[SBLANCHE,'#dcd6ff'],[AXONE,'#fff2a8'],
 [ALVEOLE,'#9ad8ff'],[LOBULE,'#e09a5a'],[NEPHRON,'#c58cff'],[TCARD,'#ff5c6c'],[VILLOSITE,'#ffd97a'],[RETINE,'#6ff0d8'],[GLANDE,'#ffbe6b'],[SYNAPSE,'#ffffff'],
 [NEURONE,'#ffe14d'],[ASTRO,'#6fe08a'],[OSTEO,'#f2ead0'],[RBC,'#ff4040'],[LYMPHO,'#dfe8ff'],[FIBRE,'#ff7a6a'],[CARDIO,'#ff5c6c'],[HEPATO,'#e0a060'],[KERATINO,'#ffc9a3'],
 [PNEUMO,'#9ad8ff'],[RENALE,'#c58cff'],[GASTRIQUE,'#ffbe6b'],[ENTERO,'#ffd97a'],[BATONNET,'#6ff0d8'],[BACTERIE,'#a8ff4d'],
 [NOYAU,'#b48cff'],[NUCLEOLE,'#8a6cff'],[CHROMATINE,'#c79bff'],[NUCLEOSOME,'#b48cff'],[MITO,'#ff9a3d'],[RE,'#55d6e8'],[GOLGI,'#ffd24d'],[LYSOSOME,'#ff5fd0'],[VESICULE,'#9fe8ff'],
 [VESSYN,'#ffe14d'],[RIBO,'#4de0b0'],[MICROTUBULE,'#8ae06f'],[MEMB,'#9fb4d8'],
 [ADN,'#4d9bff'],[ARN,'#5fe07a'],[HEMO,'#ff4d4d'],[HISTONE,'#d0a8ff'],[ANTICORPS,'#7ad0ff'],[COLLAGENE,'#f2ead0'],[KERATINE,'#ffd9a8'],[ACTINE,'#ff9a9a'],[MYOSINE,'#ff5c8a'],
 [ATPSYN,'#ffb347'],[CANAL,'#6ff0d8'],[RHODO,'#ff7ab8'],[ENZYME,'#ffa860'],[ARNPOL,'#9fe07a'],[TUBULINE,'#8ae06f'],[PORE,'#c79bff'],
 [EAU,'#7fc8ff'],[O2,'#ff6b6b'],[CO2,'#c8c8c8'],[GLUCOSE,'#ffe9a8'],[ATP,'#d8ff4d'],[BA,'#5fe07a'],[BT,'#ff6b6b'],[BG,'#ffd24d'],[BC,'#4d9bff'],[BU,'#ff9a3d'],
 [DESOXY,'#d0b0ff'],[RIBOSE,'#d0b0ff'],[PHOS,'#ffa040'],[LIPU,'#ffe08a'],[LIPD,'#ffe08a'],[HEME,'#ff4d4d'],[APATITE,'#f2ead0'],[GLU,'#ffe14d'],
 [ATOM.H,'#ffffff'],[ATOM.C,'#a8a8a8'],[ATOM.N,'#5a7dff'],[ATOM.O,'#ff4d4d'],[ATOM.P,'#ff9a2e'],[ATOM.S,'#ffe14d'],[ATOM.Ca,'#5fe07a'],[ATOM.Fe,'#e07030'],
 [PROTON,'#ff5a5a'],[NEUTRON,'#8fb0ff'],[QU,'#ff5a5a'],[QD,'#5a9bff'],[ELEC,'#5ff0e0']].forEach(q=>{q[0].hex=q[1]});
ALL.forEach(n=>{if(!n.hex)n.hex=CATCOL[n.cat]||'#e8e8e8';n.col=hex(n.hex)});
// système anatomique des organes et des structures macroscopiques (−1 partout ailleurs : tissus, cellules, molécules…)
[[CERVEAU,5],[MOELLE,5],[COEUR,3],[AORTE,3],[VEINECAVE,4],[POUMON,6],[TRACHEE,6],[LARYNX,6],[DIAPHRAGME,6],[FOIE,7],[ESTOMAC,7],[INTESTINS,7],[OESOPHAGE,7],[PANCREAS,7],[VESBIL,7],
 [REIN,8],[VESSIE,8],[THYROIDE,9],[SURRENALE,9],[HYPOPHYSE,9],[RATE,10],[THYMUS,10],[GANGLION,10],[UTERUS,11],[OVAIRE,11],[TESTICULE,11],[PROSTATE,11],[OEIL,12],[LANGUE,12],[OREILLE,12],
 [FEMUR,1],[VERTEBRE,1],[MUSCLE,2]].forEach(q=>{q[0].sys=q[1]});
// budget de taille : les nouveaux nœuds sont ramenés à un nombre de points raisonnable en éclaircissant au hasard, dans la même proportion,
// les points sans enfant et les enfants très nombreux (les enfants rares, souvent les plus parlants, restent tous)
const alleger=(n,cible)=>{const N=n.k.length,nb=n.kinds.map(()=>0);n.k.forEach(k=>{if(k!==255)nb[k]++});const leger=i=>n.k[i]===255||nb[n.k[i]]>=150;
  let m=0;for(let i=0;i<N;i++)if(leger(i))m++;const g=(cible-(N-m))/m;if(g>=1)return;
  const o={p:[],k:[],ri:[],ci:[],sy:[],ph:[]};for(let i=0;i<N;i++){if(leger(i)&&rnd()>g)continue;o.p.push(n.p[3*i],n.p[3*i+1],n.p[3*i+2]);for(const c of['k','ri','ci','sy','ph'])o[c].push(n[c][i])}Object.assign(n,o)};
ALL.slice(ALL.indexOf(NERF),ALL.indexOf(CORPS)).forEach(n=>alleger(n,2100));
ALL.forEach(seal);
return{ALL,CORPS,CORPS_F,CERVEAU,PAL,ROT,DEBUG};})();
