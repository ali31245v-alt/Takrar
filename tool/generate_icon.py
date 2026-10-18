import math, os, struct, zlib
# Draw a crisp, square launcher icon with only Python's standard library.
def png(path, n):
    rows=[]
    def inside_round(x,y,x0,y0,x1,y1,r):
        cx=min(max(x,x0+r),x1-r); cy=min(max(y,y0+r),y1-r)
        return (x-cx)**2+(y-cy)**2 <= r*r
    def poly(x,y,pts):
        hit=False
        j=len(pts)-1
        for i,(xi,yi) in enumerate(pts):
            xj,yj=pts[j]
            if ((yi>y)!=(yj>y)) and x < (xj-xi)*(y-yi)/(yj-yi+1e-9)+xi: hit=not hit
            j=i
        return hit
    # normalized drawing coordinates 0..100
    card=[(28,29),(60,21),(75,34),(75,67),(44,76),(28,61)]
    card2=[(20,36),(31,32),(31,69),(20,64)]
    arrow=[(65,18),(81,20),(76,34),(71,29),(63,36),(59,31),(68,23)]
    for py in range(n):
        row=bytearray([0])
        y=(py+.5)*100/n
        for px in range(n):
            x=(px+.5)*100/n
            if inside_round(x,y,3,3,97,97,19):
                t=max(0,min(1,y/100))
                c=(int(21-7*t),int(14-3*t),int(66+38*t))
                if poly(x,y,card2): c=(92,76,225)
                if poly(x,y,card): c=(int(199-35*t),int(169-30*t),255)
                # card face inset accent
                if poly(x,y,[(37,40),(61,34),(66,39),(42,46)]): c=(255,255,255)
                if poly(x,y,[(39,49),(63,43),(64,47),(40,53)]): c=(255,255,255)
                if poly(x,y,arrow): c=(117,65,255)
                # subtle circular brain-like mark
                if ((x-51)**2+(y-59)**2 < 7**2 and ((x-51)**2+(y-59)**2 > 4**2)): c=(120,66,245)
            else:
                c=(0,0,0,0)
            row.extend(c if len(c)==4 else (*c,255))
        rows.append(bytes(row))
    raw=b''.join(rows)
    def chunk(tag,data): return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',n,n,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
    open(path,'wb').write(data)
sizes={'mipmap-mdpi':48,'mipmap-hdpi':72,'mipmap-xhdpi':96,'mipmap-xxhdpi':144,'mipmap-xxxhdpi':192}
for folder,size in sizes.items():
    path=os.path.join('android','app','src','main','res',folder,'ic_launcher.png')
    os.makedirs(os.path.dirname(path),exist_ok=True)
    png(path,size)
    # Keep legacy round icon consistent too.
    open(os.path.join(os.path.dirname(path),'ic_launcher_round.png'),'wb').write(open(path,'rb').read())
print('Generated Takrar launcher icons.')
