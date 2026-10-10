const fs = require('fs');
const app = fs.readFileSync('app.js','utf8');
const css = fs.readFileSync('styles.css','utf8');
const schema = fs.readFileSync('schema.sql','utf8');
const migration = fs.readFileSync('MIGRATION-V18.2.sql','utf8');
const checks = [
  ['delegated clicks are not blocked by inline stopPropagation', !/onclick=["']event\.stopPropagation\(\)/.test(app)],
  ['Like and Memory have distinct symbols', app.includes('♡ Like') && app.includes('▢ Memory') && app.includes('▣ In Memory')],
  ['Whisper remains the primary expression action', /data-action="save">Whisper<\/button>/.test(app)],
  ['media preview mode selector exists', app.includes('PreviewMode') && app.includes('PreviewChoice')],
  ['cover preview metadata is persisted', app.includes('m.is_preview=previewMode===\'cover\'&&i===coverIndex') && schema.includes('is_preview boolean not null default false')],
  ['repeatable media migration exists', migration.includes('add column if not exists is_preview')],
  ['feeling/idea/vibe offer presets and custom entries', app.includes('tagFeelingCustom') && app.includes('tagIdeaCustom') && app.includes('tagVibeCustom')],
  ['location uses explicit geolocation permission', app.includes('navigator.geolocation.getCurrentPosition')],
  ['place lookup offers suggestions and manual entry', app.includes('nominatim.openstreetmap.org/search') && app.includes('select-location')],
  ['responsive composer refinements exist', css.includes('.tag-editor-refined') && css.includes('@media(max-width:680px)')],
  ['Like, Memory, Report, Reply, Share and Why this handlers exist', ['like','save-toggle','report','open','share','why-reflection'].every(x=>app.includes(`a.action==='${x}'`))],
  ['landing page uses cache-busted app.js', fs.readFileSync('index.html','utf8').includes('app.js?v=20261010-v18-future-centric')],
];
let failed=0;
for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'}: ${name}`); if(!ok)failed++;}
if(failed)process.exit(1);
