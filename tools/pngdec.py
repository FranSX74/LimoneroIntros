import zlib, struct
def decode(path):
    d=open(path,'rb').read(); pos=8; idat=b''; plte=None; trns=None
    while pos<len(d):
        ln,=struct.unpack('>I',d[pos:pos+4]); t=d[pos+4:pos+8]; body=d[pos+8:pos+8+ln]; pos+=12+ln
        if t==b'IHDR': w,h,bd,ct=struct.unpack('>IIBB',body[:10])
        if t==b'PLTE': plte=body
        if t==b'tRNS': trns=body
        if t==b'IDAT': idat+=body
    raw=zlib.decompress(idat)
    chans={0:1,2:3,3:1,4:2,6:4}[ct]; bits=bd*chans; stride=(w*bits+7)//8; bpp=max(1,bits//8)
    rows=[];prev=bytearray(stride);i=0
    for y in range(h):
        f=raw[i];i+=1;cur=bytearray(raw[i:i+stride]);i+=stride
        for x in range(stride):
            a=cur[x-bpp] if x>=bpp else 0;b=prev[x];c=prev[x-bpp] if x>=bpp else 0
            if f==1:cur[x]=(cur[x]+a)&255
            elif f==2:cur[x]=(cur[x]+b)&255
            elif f==3:cur[x]=(cur[x]+((a+b)>>1))&255
            elif f==4:
                p=a+b-c;pa=abs(p-a);pb=abs(p-b);pc=abs(p-c)
                cur[x]=(cur[x]+(a if pa<=pb and pa<=pc else b if pb<=pc else c))&255
        rows.append(cur);prev=cur
    def pix(x,y):
        r=rows[y]
        if ct==3:
            if bd==8: idx=r[x]
            else:
                per=8//bd; idx=(r[x//per]>>(8-bd*(x%per+1)))&((1<<bd)-1)
            return tuple(plte[idx*3:idx*3+3])+((trns[idx] if trns and idx<len(trns) else 255),)
        if ct==6: return tuple(r[x*4:x*4+4])
        if ct==2: return tuple(r[x*3:x*3+3])+(255,)
        return (r[x],)*3+(255,)
    return w,h,pix
