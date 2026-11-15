// Validación de datos y del contenedor .mod, sin cargar una campaña.
const fs=require('fs'),path=require('path'),assert=require('assert');
const base=path.resolve(__dirname,'../..'),source=path.join(base,'modules/aptus_initial_ammunition');
const xml=fs.readFileSync(path.join(source,'client.xml'),'utf8');
const definition=fs.readFileSync(path.join(source,'definition.xml'),'utf8');
const expected=[
 ['9×19 mm','Bala de pistola utilizada habitualmente en pistolas semiautomáticas y subfusiles.'],
 ['.45 ACP','Bala de pistola utilizada habitualmente en pistolas semiautomáticas de calibre .45.'],
 ['.40 S&W','Bala de pistola utilizada habitualmente en pistolas semiautomáticas.'],
 ['.38 Special','Bala de revólver utilizada habitualmente en revólveres de calibre .38.'],
 ['.357 Magnum','Bala de revólver utilizada habitualmente en revólveres de calibre .357 Magnum.'],
 ['.44 Magnum','Bala de revólver utilizada habitualmente en revólveres de gran calibre.'],
 ['5,56×45 mm','Bala de fusil utilizada habitualmente en fusiles de asalto y carabinas.'],
 ['7,62×39 mm','Bala de fusil utilizada habitualmente en fusiles de asalto y carabinas.'],
 ['7,62×51 mm','Bala de fusil utilizada habitualmente en fusiles de combate y rifles de precisión.'],
 ['.308 Winchester','Bala de rifle utilizada habitualmente en rifles de caza y rifles de precisión.'],
 ['.30-06 Springfield','Bala de rifle utilizada habitualmente en rifles de caza.'],
 ['Calibre 12','Cartucho de escopeta utilizado habitualmente en escopetas de calibre 12.'],
 ['Calibre 20','Cartucho de escopeta utilizado habitualmente en escopetas de calibre 20.'],
 ['.410','Cartucho de escopeta utilizado habitualmente en escopetas de calibre .410.'],
 ['Granada 40 mm','Granada utilizada habitualmente como munición de lanzagranadas de 40 mm.'],
 ['Flecha','Proyectil utilizado habitualmente como munición de arcos.'],
 ['Virote','Proyectil utilizado habitualmente como munición de ballestas.']
];
const decode=s=>s.replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>');
function tree(text){
 const root={children:[]},stack=[root];
 const clean=text.replace(/<\?[\s\S]*?\?>|<!--[\s\S]*?-->/g,'');
 for(const token of clean.match(/<[^>]*>|[^<]+/g)||[]){
  if(!token.startsWith('<')){stack.at(-1).text=(stack.at(-1).text||'')+token;continue;}
  if(token.startsWith('</')){assert.equal(stack.pop().tag,token.slice(2,-1));continue;}
  const tag=token.match(/^<([\w.-]+)/)?.[1];assert(tag);
  const node={tag,children:[],attrs:Object.fromEntries([...token.matchAll(/([\w.-]+)="([^"]*)"/g)].map(m=>[m[1],m[2]]))};
  stack.at(-1).children.push(node);if(!token.endsWith('/>'))stack.push(node);
 }assert.equal(stack.length,1);return root.children[0];
}
const child=(node,tag)=>node.children.find(c=>c.tag===tag);
const value=(node,tag)=>decode(child(node,tag)?.text||'');
const root=tree(xml),ref=child(root,'reference'),records=child(ref,'aptus_equipment_templates').children;
assert.equal(records.length,17);assert.equal(ref.attrs.static,'true');
assert.deepEqual(records.map(r=>[value(r,'name'),value(child(r,'properties'),'description')]),expected);
assert.equal(new Set(records.map(r=>r.tag)).size,17);
assert.equal(new Set(records.map(r=>value(r,'template_id'))).size,17);
const fields=fs.readFileSync(path.join(base,'scripts/manager_aptus_equipment.lua'),'utf8');
const defaults=[...fields.matchAll(/key = "([^"]+)", path = "([^"]+)", kind = "([^"]+)", default = ([^ }]+)/g)];
const keys=['9x19mm','45acp','40sw','38special','357magnum','44magnum','556x45mm','762x39mm','762x51mm','308winchester','3006springfield','calibre12','calibre20','410','granada40mm','flecha','virote'];
const configuration=[[50,50],[50,50],[50,50],[50,50],[50,50],[20,20],[20,20],[20,20],[20,20],[20,20],[20,20],[25,25],[25,25],[25,25],[6,3],[12,12],[12,12]];
const assignedImages=['municion_9_19_mm.png','municion_45_ACP.png','municion_9_19_mm.png',
 'municion_38_Special.png','municion_38_Special.png','municion_balas_gordas.png',
 ...Array(5).fill('municion_por_defecto.png'),...Array(3).fill('municion_cartuchosl.png'),
 ...Array(3).fill('municion_por_defecto.png')];
const catalogue=JSON.parse(fs.readFileSync(path.join(source,'catalogue.json'),'utf8'));
assert.equal(catalogue.length,17);
for(const [i,r] of records.entries()){
 assert.equal(r.tag,'ammo-'+keys[i]);assert.equal(value(r,'template_id'),'aptus.initial.ammunition.'+keys[i]);
 assert.equal(value(r,'template_version'),'2');assert.equal(value(r,'schema_version'),'1');
 for(const [,key,p,kind,raw] of defaults){
  if(['name','description','picture','type_id','stackable','max_stack','load_every','load_value'].includes(key))continue;
  let node=r;for(const part of p.split('.'))node=child(node,part);
  assert(node,p);assert.equal(node.attrs.type,kind);assert.equal(node.text,raw);
 }
 const properties=child(r,'properties');
 assert.equal(value(properties,'type_id'),'ammunition');assert.equal(value(properties,'stackable'),'1');
 assert.equal(value(properties,'max_stack'),String(configuration[i][0]));
 assert.equal(value(properties,'load_every'),String(configuration[i][1]));assert.equal(value(properties,'load_value'),'1');
 const picture=child(properties,'picture');assert.equal(picture.attrs.type,'token');
 assert.equal(catalogue[i].image,assignedImages[i]);
 assert.equal(picture.text,'graphics/'+catalogue[i].image+'@APTUS Initial Ammunition');
 assert(!child(properties,'profiles')&&!child(properties,'qualities'));
}
assert(!/inventorylist|charsheet|aptus\.container|<public|<holder|<script/.test(xml));
assert.equal(value(tree(definition),'name'),'APTUS Initial Ammunition');
assert.equal(value(tree(definition),'ruleset'),'CoreRPG');
const zip=fs.readFileSync(path.join(base,'modules/APTUS_Initial_Ammunition.mod'));
const end=zip.length-22;assert.equal(zip.readUInt32LE(end),0x06054b50);assert.equal(zip.readUInt16LE(end+10),8);
let central=zip.readUInt32LE(end+16);
const names=[];
for(let i=0;i<8;i++){
 assert.equal(zip.readUInt32LE(central),0x02014b50);assert.equal(zip.readUInt16LE(central+10),0);
 const len=zip.readUInt16LE(central+28),name=zip.subarray(central+46,central+46+len).toString();names.push(name);
 const offset=zip.readUInt32LE(central+42);assert.equal(zip.readUInt32LE(offset),0x04034b50);
 const start=offset+30+zip.readUInt16LE(offset+26)+zip.readUInt16LE(offset+28);
 const data=zip.subarray(start,start+zip.readUInt32LE(central+24));
 assert(data.equals(fs.readFileSync(path.join(source,name))));
 if(name.endsWith('.png')){assert.equal(data.readUInt32BE(16),192);assert.equal(data.readUInt32BE(20),192);}
 let crc=0xffffffff;for(const byte of data){crc^=byte;for(let bit=0;bit<8;bit++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}
 assert.equal((crc^0xffffffff)>>>0,zip.readUInt32LE(central+16));
 central+=46+len+zip.readUInt16LE(central+30)+zip.readUInt16LE(central+32);
}
const images=[...new Set(catalogue.map(r=>'graphics/'+r.image))].sort();assert.equal(images.length,6);
assert.deepEqual(names,['definition.xml','client.xml',...images]);
// Validación aritmética de los datos: no ejecuta operaciones de inventario.
for(const [index,quantity,expected] of [[0,120,[50,50,20]],[11,40,[25,15]],[14,10,[6,4]]]){
 const [max,every]=configuration[index];let remaining=quantity;const piles=[];
 while(remaining>0){piles.push(Math.min(max,remaining));remaining-=piles.at(-1);}
 assert.deepEqual(piles,expected);assert.equal(piles.reduce((a,b)=>a+b,0),quantity);
 if(index===0||index===11)for(const count of piles)assert.equal(Math.ceil(count/every),1);
}
for(const [index,counts,loads] of [[0,[1,20,50],[1,1,1]],[11,[1,15,25],[1,1,1]],[14,[1,2,3,4,5,6],[1,1,1,2,2,2]]]){
 assert.deepEqual(counts.map(count=>Math.ceil(count/configuration[index][1])),loads);
}
console.log('OK: 17 registros e identidades estables, límites/tramos, aritmética de ejemplos, 6 PNG 192×192 sin transformación, referencias y ZIP/CRC. No ejecuta el inventario.');
