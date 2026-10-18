"""Merge valuable definitions without regenerating unrelated equipment data."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
from balance_rules import LOOT_WEIGHTS
def entries():
    spec=json.loads((ROOT/'data/valuable_catalog.json').read_text('utf8'))
    result=[]
    for value in spec['items']:
        item=dict(value,kind='loot',category='valuable')
        item['sell_price']=round(item['price']*.56)
        item['drop_weight']=LOOT_WEIGHTS[item['rarity']]
        item['visual_model']='res://assets/valuables/'+item['id']+'.glb'
        result.append(item)
    return result
if __name__=='__main__':
    path=ROOT/'data/items.json';data=json.loads(path.read_text('utf8'))
    data['items']=[item for item in data['items'] if item['kind']!='loot']+entries()
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n','utf8')
    print('VALUABLE_CATALOG',len(entries()),'items merged')
