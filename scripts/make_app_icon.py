"""
生成 App 图标：把 App 里那枚硬币（同一张币面图 + 同一张浮雕法线图）斜着放，
左上打一束强光，做出"明暗分明"的金属感。

用法（在项目根目录）：  python3 scripts/make_app_icon.py
输出：CoinFlip/Assets.xcassets/AppIcon.appiconset/icon_1024.png（不透明，1024×1024）

作者定下的参数（改之前先问）：
  • 月面朝上
  • 硬币大小 scale=0.3014（第一版 0.41 → 缩小 30% → 再放大 5%）
  • 下沿滚边的反光线：lip 宽 0.13×厚度，侧面轮廓泛光 (1-|n·z|)^3
"""
import numpy as np, sys, os
from PIL import Image
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R_=os.path.join(ROOT,'CoinFlip','Resources')+'/' 
def load(f): return np.asarray(Image.open(R_+f).convert('RGB')).astype(np.float32)/255
def rot(ax,deg):
    a=np.radians(deg);c,s=np.cos(a),np.sin(a)
    if ax=='x': return np.array([[1,0,0],[0,c,-s],[0,s,c]])
    if ax=='y': return np.array([[c,0,s],[0,1,0],[-s,0,c]])
    return np.array([[c,-s,0],[s,c,0],[0,0,1]])
def norm(v): return v/np.linalg.norm(v,axis=-1,keepdims=True)
def sample(img,u,v):
    H,W,_=img.shape
    x=np.clip(u*(W-1),0,W-1); y=np.clip((1-v)*(H-1),0,H-1)
    x0=np.floor(x).astype(int);y0=np.floor(y).astype(int);x1=np.minimum(x0+1,W-1);y1=np.minimum(y0+1,H-1)
    fx=(x-x0)[...,None];fy=(y-y0)[...,None]
    return (img[y0,x0]*(1-fx)+img[y0,x1]*fx)*(1-fy)+(img[y1,x0]*(1-fx)+img[y1,x1]*fx)*fy
L=norm(np.array([-0.55,0.75,0.6]))
LS=norm(np.array([-0.35,0.95,-0.1]))
def env(r):
    k=np.clip((r@LS),-1,1)
    soft=np.exp(-(1-k)*2.2)*1.9
    rim=np.exp(-(1-np.clip(r@norm(np.array([0.5,0.6,0.6])),-1,1))*30)*1.2
    return 0.02+soft+rim
def render(face='moon',size=1024,ss=2,rx=-42,rz=-24,ry=0,scale=0.3014):
    alb=load(f'{face}_silver.png'); nm=load(f'{face}_silver_normal.png')*2-1
    N=size*ss; R=1.0; t=0.167
    M=rot('z',rz)@rot('y',ry)@rot('x',rx)
    Mi=M.T
    ys,xs=np.mgrid[0:N,0:N]
    px=(xs+0.5)/N*2-1; py=1-(ys+0.5)/N*2
    px/=scale*2; py/=scale*2
    o=np.stack([px,py,np.full_like(px,10)],-1)@Mi.T   # local origin
    d=(np.array([0,0,-1.0])@Mi.T)
    img=np.zeros((N,N,3),np.float32); depth=np.full((N,N),np.inf)
    # front & back face
    for zf,sgn in((t/2,1),(-t/2,-1)):
        if abs(d[2])<1e-6: continue
        s=(zf-o[...,2])/d[2]; p=o+s[...,None]*d
        r2=p[...,0]**2+p[...,1]**2
        hit=(r2<=R*R)&(s<depth)&(sgn*d[2]<0)
        if not hit.any(): continue
        u=p[...,0]*0.5+0.5; v=p[...,1]*0.5+0.5
        if sgn<0: u=1-u
        a=sample(alb,u,v); n=sample(nm,u,v); n=norm(n)
        n=n*np.array([1 if sgn>0 else -1,1,sgn])
        wn=norm(n@M.T)
        view=np.array([0,0,1.0]); refl=2*(wn@view)[...,None]*wn-view
        diff=np.clip(wn@L,0,1)[...,None]
        tt=(-0.6*px+0.8*py)*scale*2
        g=0.12+1.1/(1+np.exp(-tt*3.2))
        col=a*(0.12*diff+0.9*env(refl)[...,None])*g[...,None]
        img[hit]=col[hit]; depth[hit]=s[hit]
    # side
    A=d[0]**2+d[1]**2; B=2*(o[...,0]*d[0]+o[...,1]*d[1]); C=o[...,0]**2+o[...,1]**2-R*R
    disc=B*B-4*A*C; ok=disc>=0
    s=(-B-np.sqrt(np.maximum(disc,0)))/(2*A)
    p=o+s[...,None]*d
    hit=ok&(np.abs(p[...,2])<=t/2)&(s<depth)
    ang=np.arctan2(p[...,1],p[...,0])
    rn=np.stack([np.cos(ang),np.sin(ang),np.zeros_like(ang)],-1)
    ridge=np.sin(ang*160)*0.25
    tn=np.stack([-np.sin(ang),np.cos(ang),np.zeros_like(ang)],-1)
    ln=norm(rn+ridge[...,None]*tn)
    wn=norm(ln@M.T); view=np.array([0,0,1.0]); refl=2*(wn@view)[...,None]*wn-view
    tt=(-0.6*px+0.8*py)*scale*2
    g=0.15+1.0/(1+np.exp(-tt*3.2))
    col=np.array([0.78,0.8,0.84])*(0.1*np.clip(wn@L,0,1)[...,None]+0.85*env(refl)[...,None])*g[...,None]
    lip=np.exp(-((p[...,2]+t/2)/(0.13*t))**2)
    fres=(1-np.abs(wn[...,2]))**3
    rimc=np.array([0.85,0.88,0.95])*(0.55*lip+0.5*fres)[...,None]
    col=col+rimc
    img[hit]=col[hit]
    cov=np.isfinite(depth)|hit
    img=1-np.exp(-img*2.3)            # 柔和压高光
    img=np.clip(img,0,1)**(1/1.15)
    bg=np.zeros_like(img)
    out=np.where(cov[...,None],img,bg)
    im=Image.fromarray((out*255).astype(np.uint8)).resize((size,size),Image.LANCZOS)
    return im
if __name__=='__main__':
    out=os.path.join(ROOT,'CoinFlip','Assets.xcassets','AppIcon.appiconset','icon_1024.png')
    render('moon').convert('RGB').save(out)
    print('已写入', out)
