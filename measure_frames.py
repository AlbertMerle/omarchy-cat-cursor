"""Measure source alpha bounds; emit runtime crops without altering artwork."""
import subprocess, re, json
states={'idle':(25,130,132,180,8),'run':(17,355,135,180,9),'fly':(20,580,135,180,7),'attack':(20,810,132,180,5),'sleep':(25,1000,132,180,5),'dash':(695,810,137,180,4)}
rects={k:[(x+i*w,y,w,h) for i in range(n)] for k,(x,y,w,h,n) in states.items()}
rects['fall']=[(1090,155,145,180),(965,580,130,180),(1095,580,145,180)]
result={}
for state, cells in rects.items():
 result[state]=[]
 for x,y,w,h in cells:
  out=subprocess.check_output(['magick','cat-mister-actions.png','-crop',f'{w}x{h}+{x}+{y}','+repage','-alpha','extract','-threshold','40%','-format','%@','info:'],text=True)
  bw,bh,bx,by=map(int,re.fullmatch(r'(\d+)x(\d+)\+(\d+)\+(\d+)',out).groups())
  result[state].append([x+bx,y+by,bw,bh])
print(json.dumps(result))
