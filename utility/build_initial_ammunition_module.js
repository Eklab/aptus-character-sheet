// Empaquetado ZIP sin compresión ni dependencias. No accede a campañas ni a FGU.
// Ejecutar: node utility/build_initial_ammunition_module.js
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'modules/aptus_initial_ammunition');
const target = path.join(root, 'modules/APTUS_Initial_Ammunition.mod');
const moduleName = 'APTUS Initial Ammunition';
const catalogue = JSON.parse(fs.readFileSync(path.join(source, 'catalogue.json'), 'utf8'));
if (catalogue.length !== 17 || new Set(catalogue.map(r => r.node)).size !== 17
    || new Set(catalogue.map(r => r.template_id)).size !== 17) throw Error('Catálogo inválido: se requieren 17 identidades únicas.');
const images = [...new Set(catalogue.map(r => r.image))].sort();
for (const image of images) {
  if (!/^[\w.-]+\.png$/.test(image)) throw Error('Ruta de imagen no válida: ' + image);
  const data = fs.readFileSync(path.join(source, 'graphics', image));
  if (!data.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))
      || data.readUInt32BE(16) !== 192 || data.readUInt32BE(20) !== 192) throw Error('Se requiere PNG de 192 × 192: ' + image);
}
const escape = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const records = catalogue.map(record => {
  for (const key of ['max_stack', 'load_every', 'load_value']) {
    if (!Number.isSafeInteger(record[key]) || record[key] < 1) throw Error('Valor inválido: ' + key);
  }
  if (!/^ammo-[\w-]+$/.test(record.node)) throw Error('Identificador de nodo no válido');
  return `            <${record.node}>
                <name type="string">${escape(record.name)}</name>
                <template_id type="string">${escape(record.template_id)}</template_id>
                <template_version type="number">2</template_version>
                <schema_version type="number">1</schema_version>
                <locked type="number">1</locked>
                <properties>
                    <type_id type="string">ammunition</type_id>
                    <description type="string">${escape(record.description)}</description>
                    <picture type="token">graphics/${escape(record.image)}@${moduleName}</picture>
                    <stackable type="number">1</stackable>
                    <max_stack type="number">${record.max_stack}</max_stack>
                    <is_container type="number">0</is_container>
                    <is_wealth type="number">0</is_wealth>
                    <load_every type="number">${record.load_every}</load_every>
                    <load_value type="number">${record.load_value}</load_value>
                    <capacity type="number">0</capacity>
                    <required_fue type="number">0</required_fue>
                    <required_agi type="number">0</required_agi>
                    <defense><pro type="number">0</pro><def type="number">0</def><agi type="number">0</agi><per type="number">0</per></defense>
                </properties>
            </${record.node}>`;
}).join('\n');
fs.writeFileSync(path.join(source, 'client.xml'), `<?xml version="1.0" encoding="utf-8"?>
<root version="4.1" release="2">
    <reference static="true">
        <aptus_equipment_templates>
${records}
        </aptus_equipment_templates>
    </reference>
</root>
`);
function crc32(data) {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
const files = [], directory = [];
let offset = 0;
const entries = ['definition.xml', 'client.xml', ...images.map(image => 'graphics/' + image)];
for (const name of entries) {
  const filename = Buffer.from(name), data = fs.readFileSync(path.join(source, name));
  const crc = crc32(data);
  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50, 0); local.writeUInt16LE(20, 4);
  local.writeUInt16LE(0x800, 6); local.writeUInt16LE(33, 12); // UTF-8; fecha fija 1980-01-01
  local.writeUInt32LE(crc, 14); local.writeUInt32LE(data.length, 18);
  local.writeUInt32LE(data.length, 22); local.writeUInt16LE(filename.length, 26);
  const central = Buffer.alloc(46);
  central.writeUInt32LE(0x02014b50, 0); central.writeUInt16LE(20, 4);
  central.writeUInt16LE(20, 6); central.writeUInt16LE(0x800, 8); central.writeUInt16LE(33, 14);
  central.writeUInt32LE(crc, 16); central.writeUInt32LE(data.length, 20);
  central.writeUInt32LE(data.length, 24); central.writeUInt16LE(filename.length, 28);
  central.writeUInt32LE(offset, 42);
  files.push(local, filename, data); directory.push(central, filename);
  offset += local.length + filename.length + data.length;
}
const central = Buffer.concat(directory), end = Buffer.alloc(22);
end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(entries.length, 8); end.writeUInt16LE(entries.length, 10);
end.writeUInt32LE(central.length, 12); end.writeUInt32LE(offset, 16);
fs.writeFileSync(target, Buffer.concat([...files, central, end]));
console.log('Módulo generado: ' + target);
