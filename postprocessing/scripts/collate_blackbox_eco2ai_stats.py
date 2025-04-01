import pandas as pd
import json
import numpy as np
from glob import glob
from tqdm import tqdm
import os
import sys
from improving_names import *

rdir = '../../results_blackbox/'
if len(sys.argv) > 1:
    rdir = sys.argv[1]
else:
    print('no rdir provided, using',rdir)
    
print('reading results from  directory', rdir)
    
##########
# load data from json
##########
frames = []
comparison_cols = [
    'dataset',
    'algorithm',
    'random_state',
    'experiment_description', # ml method, random seed
    'duration(s)',
    'power_consumption(kWh)',
    'CO2_emissions(kg)',
    'CPU_name',
    'GPU_name',
    'cost'
]

fails = []
import pdb
for f in tqdm(glob(rdir + '/*/*_eco2ai.csv')):
    if 'cv_results' in f: 
        continue

    # leave out symbolic data
    if 'feynman_' in f or 'strogatz_' in f:
        continue

    # leave out LinearReg, Lasso (we have SGD with penalty)
    if any([m in f for m in ['LinearRegression','Lasso','EHCRegressor']]):
        continue

    try: 
        df = pd.read_csv(f, header=0)
        
        if df.shape[0]==0:
            raise Exception("Empty dataframe")
        
        frames.append(df) 
    except Exception as e:
        fails.append([f,e])
        pass
    
print(len(fails),'fails:',fails)

df_results = pd.concat(frames, ignore_index=True)

##########
# cleanup
##########
df_results = df_results.rename(columns={'project_name':'dataset'})
df_results[['algorithm', 'random_state']] = df_results['experiment_description'].str.split(expand=True)
df_results['random_state'] = df_results['random_state'].apply(np.nan_to_num).astype(int)

# df_results = df_results.drop(columns=['id', 'epoch', 'experiment_description'])
df_results = df_results[comparison_cols]

####################
# Improving names
####################
df_results = improve_names(df_results)
df_results = add_metadata(df_results)

# Only SR methods --- excluding sklearn stuff
df_results = df_results[df_results["symbolic_alg"]==True].reset_index(drop=True)

for col in ['algorithm','dataset']:
    print(df_results[col].nunique(), col+'s')

###############################
# save results and summary data
###############################
if not os.path.exists('../../results/black-box/'):
    os.makedirs('../../results/black-box/')
    
df_results.to_feather('../../results/black-box/power_consumption.feather')
print('eco2ai data saved to ../../results/black-box/power_consumption.feather')

########
print('mean trial count:')
print(df_results.groupby('algorithm')['dataset'].count().sort_values()
      / df_results.dataset.nunique())