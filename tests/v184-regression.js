const fs=require('fs');const path=require('path');const root=path.resolve(__dirname,'..');
const app=fs.readFileSync(path.join(root,'app.js'),'utf8');const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const checks=[
 ['Home title restored with mobile-first structure',/home-feed-page[\s\S]{0,120}shell\('Home'\)[\s\S]{0,120}feedModeNav\(\)[\s\S]{0,120}mobileComposerTrigger\(\)[\s\S]{0,120}composer\(\)[\s\S]{0,100}id=\"feed\"/.test(app)],
 ['Whispering headline removed',!app.includes("shell('Whispering'")],
 ['Removed Home subtitle',!app.includes('Put down a Whisper, then encounter reflections worth returning to.')],
 ['Follow post action on feed cards',/data-action="subscription-toggle" data-id="\$\{esc\(w\.id\)\}" aria-pressed="false">＋ Follow post/.test(app)],
 ['Follow post action on detail page',app.includes('title="Follow this post to receive notifications about new replies."')],
 ['Post follow/unfollow state hydrates',app.includes("'✓ Following post':'＋ Follow post'")],
 ['Person follow/unfollow remains available',app.includes("data-action=\"unfollow\"")&&app.includes("data-action=\"follow\"")],
 ['Mobile Home returns to top and focuses composer',app.includes(".mobile-nav a[href=\"#home\"]")&&app.includes("scrollTo({top:0,behavior:'smooth'})")],
 ['Release cache key is current and CSS/JS keys match',(()=>{const css=html.match(/href=\"\.\/styles\.css\?v=([^\"]+)/);const js=html.match(/src=\"\.\/app\.js\?v=([^\"]+)/);return !!css&&!!js&&css[1]===js[1]&&js[1]==='20261026-v18.7-scaling-prep'})()]
];let failed=false;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} ${name}`);if(!ok)failed=true}if(failed)process.exit(1);
