#!/usr/bin/env python3
"""Plot actual Godot damage samples produced by tests/test_screen_damage.gd."""
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties

ROOT=Path(__file__).resolve().parents[1]
report=json.loads((ROOT/'docs/damage-curve-report.json').read_text())
font=FontProperties(fname=str(ROOT/'assets/fonts/NotoSansSC.ttf'))
plt.rcParams.update({'font.size':11, 'axes.spines.top':False, 'axes.spines.right':False})
fig,(ax,rate)=plt.subplots(2,1,figsize=(10.2,7.3),gridspec_kw={'height_ratios':[2,1]},constrained_layout=True)
points=report['samples']
edge=report['screens'][-1]['farthest_visible_distance']
ax.axvspan(0,edge,color='#e1f1eb',label='参考手机视野')
ax.plot([x['distance'] for x in points],[x['damage'] for x in points],color='#246b78',linewidth=2.6)
ax.scatter([edge],[20.5],color='#c66a2b',s=48,zorder=3)
ax.annotate('最远可见边缘  20.5',xy=(edge,20.5),xytext=(59,22),fontproperties=font,arrowprops={'arrowstyle':'->','color':'#9a5728'},color='#9a5728')
ax.set_title('屏幕内缓慢衰减，距离越远每米损失越大',fontproperties=font,fontsize=17,pad=15)
ax.set_ylabel('每次命中伤害',fontproperties=font)
ax.set_xlim(0,120);ax.set_ylim(0,25);ax.grid(alpha=.18)
for d in [0,10,20,30,50,80,100]:
    p=points[d]
    ax.scatter([d],[p['damage']],s=16,color='#246b78')
    if d in [0,10,50,80]:
        ax.annotate(f"{p['damage']:.2f}",xy=(d,p['damage']),xytext=(4,-15),textcoords='offset points',fontsize=10,color='#24464c')
inside=[x for x in points if x['distance']<=100]
rate.axvspan(0,edge,color='#e1f1eb')
rate.plot([x['distance'] for x in inside],[x['loss_next_metre'] for x in inside],color='#c66a2b',linewidth=2.3)
rate.set_xlim(0,120);rate.set_ylim(bottom=0);rate.grid(alpha=.18)
rate.set_xlabel('实际命中距离（米）',fontproperties=font)
rate.set_ylabel('再远 1 米损失的伤害',fontproperties=font)
rate.set_title('芦苇 R9 · 普通弹 · 守卫防护 22；21:9 正常跟随镜头作为视野参考',fontproperties=font,fontsize=10,pad=10)
for axis in [ax,rate]:
    axis.tick_params(labelsize=10)
fig.savefig(ROOT/'docs/damage-curve.png',dpi=160)
print('Saved docs/damage-curve.png from actual Godot damage samples')
