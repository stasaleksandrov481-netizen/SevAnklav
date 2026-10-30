"""Bake connected straight wall sections from the existing lower-bunker mesh.
The game loads the baked JSON/RES; players never need Python.
"""
import json, math
from pathlib import Path
BASE=Path(__file__).resolve().parents[2]/'iso/maps/level2'
vertices=[];faces=[]
for line in (BASE/'WallMesh.obj').read_text().splitlines():
    fields=line.split()
    if not fields:continue
    if fields[0]=='v':vertices.append(tuple(map(float,fields[1:4])))
    elif fields[0]=='f':faces.append([int(x.split('/')[0])-1 for x in fields[1:]])
planes={}
for face in faces:
    a,b,c=(vertices[i] for i in face[:3])
    u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
    n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
    length=math.sqrt(sum(x*x for x in n))
    if length<1e-8 or abs(n[1])/length>.1:continue
    nx,nz=n[0]/length,n[2]/length
    if nx<-.001 or (abs(nx)<.001 and nz<0):nx,nz=-nx,-nz
    d=nx*a[0]+nz*a[2];t=[-nz*vertices[i][0]+nx*vertices[i][2] for i in face]
    key=(round(nx,3),round(nz,3),round(d/.02))
    planes.setdefault(key,[]).append((min(t),max(t)))
sides=[]
for (nx,nz,step),intervals in planes.items():
    intervals.sort();runs=[]
    for lo,hi in intervals:
        if runs and lo<=runs[-1][1]+.025:runs[-1][1]=max(runs[-1][1],hi)
        else:runs.append([lo,hi])
    for lo,hi in runs:
        if hi-lo>.10:sides.append(dict(n=[nx,nz],d=step*.02,lo=lo,hi=hi))
parents=list(range(len(sides)))
def root(i):
    while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
    return i
for i,a in enumerate(sides):
    for j in range(i):
        b=sides[j]
        if sum(a['n'][k]*b['n'][k] for k in [0,1])<.999 or abs(a['d']-b['d'])>.80:continue
        overlap=min(a['hi'],b['hi'])-max(a['lo'],b['lo'])
        if overlap>.8*min(a['hi']-a['lo'],b['hi']-b['lo']):parents[root(i)]=root(j)
groups={}
for i,a in enumerate(sides):groups.setdefault(root(i),[]).append(a)
sections=[]
for group in groups.values():
    n=group[0]['n'];d=sum(s['d'] for s in group)/len(group)
    lo=min(s['lo'] for s in group);hi=max(s['hi'] for s in group)
    a=[n[0]*d-n[1]*lo,n[1]*d+n[0]*lo];b=[n[0]*d-n[1]*hi,n[1]*d+n[0]*hi]
    sections.append({'a':a,'b':b,'normal':n,'width':max(.12,max(s['d'] for s in group)-min(s['d'] for s in group))})
sections.sort(key=lambda s:(s['a'][0],s['a'][1],s['b'][0]))
assert len(sections)<512
(BASE/'wall_sections.json').write_text('{\n  \"sections\": [\n'+',\n'.join('    '+json.dumps(s,separators=(',',':')) for s in sections)+'\n  ]\n}\n')
print(f'{len(faces)} source triangles, {len(sections)} connected sections')
