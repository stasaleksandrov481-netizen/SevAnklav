"""Pack the editable overhead SVG modules without changing their artwork."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[2]
folder=root/'assets/bunker/v10'
names=['medical','research','security','archive','power','access','emergency','personal','server','locker','bench','gurney','sofa','coffee','paper','carrier']
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="800" height="448" viewBox="0 0 800 448">']
for i,name in enumerate(names):
    source=(folder/(name+'.svg')).read_text()
    width,height=(30,38) if name=='paper' else ((22,35) if name=='carrier' else (200,112))
    inside=re.fullmatch(r'<svg[^>]*>(.*)</svg>\s*',source,re.S).group(1)
    ids=re.findall(r'id="([^"]+)"',inside)
    for key in ids: inside=inside.replace('id="'+key+'"','id="'+name+'_'+key+'"').replace('url(#'+key+')','url(#'+name+'_'+key+')')
    parts.append(f'<g transform="translate({i%4*200+(200-width)/2} {i//4*112+(112-height)/2})">{inside}</g>')
parts.append('</svg>')
(folder/'furniture_atlas.svg').write_text(''.join(parts))
