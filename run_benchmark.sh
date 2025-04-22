# Cheat sheet on how to run experiments. Inspired by
# https://cavalab.org/srbench/user-guide/#reproducing-the-experiment
# To run it locally: use --local flag, instead of --slurm. Experiments are
# designed to run on a slurm HPC.

# if you want to run for a specific dataset, instead of all datasets in a directory,
# please refer to the dataset name ending with tsv.gz

# sklearn_adaboost,sklearn_lasso,sklearn_mlp,sklearn_randomforest,sklearn_ridge,sklearn_sgd,sklearn_linear
# cpu_ml="geneticengine_hc,geneticengine_1p1,geneticengine_rs"
cpu_ml="afp,afp_fe,afp_ehc,bingo,brush,bsr,eplex,eql,feat,ffx,geneticengine,gpgomea,gplearn,gpzgd,itea,operon,ps-tree,pysr,qlattice,rils-rols,tir"
cpu_q="bch-compute,bch-compute-pe"

# pretrained models or checkpoints for NN based methods.
gpu_ml="e2et,nesymres,tpsr,udsr"
gpu_q="bch-gpu-pe"

################################################################################
# Cleaning log files and previous results (danger zone)
################################################################################

# # Cleaning up ENTIRE log and debug
# find results_blackbox/ -name "*.err" -type f -delete
# find results_blackbox/ -name "*.out" -type f -delete

# # Create backup files for specific algorithm
# find results_blackbox/ -name "*_ALG_NAME_*.*" -type f -exec sh -c 'mv "$0" "${0%.bak}.bak"' {} \;

# # cleaning up specific algorithm
# find results_blackbox/ -name "*_ALG_NAME_*.*" -type f -delete

# printing/Cleaning all log and debug files for all experiment folders
# find . -regex './results_.*/.*.\(err\|out\)$' -type f -delete

################################################################################
# 1. Black-box experiments - out of the box performance
################################################################################

if false; then
    python experiment/analyze.py datasets/blackbox/ \
        -script evaluate_model \
        -results results_blackbox/ \
        -images /lab-share/CHIP-Lacava-e2/Public/guilherme/singularity_images/ \
        -n_trials 30 -job_time_limit 4:00 -fit_time_limit 3600 \
        -m 4000 -max_samples 40000 \
        -q $cpu_q --scale_x --scale_y \
        --slurm --save_population --ecotracker \
        -ml $cpu_ml

    python experiment/analyze.py datasets/blackbox/ \
        -script evaluate_model \
        -results results_blackbox/ \
        -images /lab-share/CHIP-Lacava-e2/Public/guilherme/singularity_images/ \
        -pretrained_dir /lab-share/CHIP-Lacava-e2/Public/guilherme/srbench_pretrained/ \
        -n_trials 30 -job_time_limit 4:00 -fit_time_limit 3600 \
        -m 4000 -max_samples 40000 \
        -q $gpu_q --scale_x --scale_y \
        --slurm --save_population --ecotracker \
        -ml $gpu_ml
fi;

# Glue them with `python postprocessing/scripts/collate_experiments_results.py './results_blackbox/' './results/black-box/'`
# Glue eco2ai with `python postprocessing/scripts/collate_blackbox_eco2ai_stats.py './results_blackbox_' './results/black-box/'`

################################################################################
# 2. Black-box experiments - with gridsearch for each dataset-run
################################################################################
# Instead of using a global parameter as the tuned version, we fine-tune each
# algorithm for each dataset.
# It will use 6*fit_time_limit for the gridsearch, and 1*fit_time_limit for final
# evaluation. job_time_limit must have some extra time to allow for script-specific
# calculations.
# Just a reminder - it will perform a 3-fold cv for each gridsearch configuration!

if true; then
    python experiment/analyze.py datasets/blackbox/ \
        -script optimize_model \
        -results results_blackbox_tuning/ \
        -images /lab-share/CHIP-Lacava-e2/Public/guilherme/singularity_images/ \
        -n_trials 30 -job_time_limit 8:00 -fit_time_limit 3600 \
        -m 3000 -max_samples 40000 -q 'bch-compute-pe' \
        --scale_x --scale_y --slurm --ecotracker \
        -ml $cpu_ml

    python experiment/analyze.py datasets/blackbox/ \
        -script optimize_model \
        -results results_blackbox_tuning/ \
        -images /lab-share/CHIP-Lacava-e2/Public/guilherme/singularity_images/ \
        -pretrained_dir /lab-share/CHIP-Lacava-e2/Public/guilherme/srbench_pretrained/ \
        -n_trials 30 -job_time_limit 8:00 -fit_time_limit 3600 \
        -m 8000 -max_samples 40000 -q $gpu_q \
        --scale_x --scale_y --slurm --ecotracker \
        -ml $gpu_ml
fi;

# Glue them with `python postprocessing/scripts/collate_experiments_results.py './results_blackbox_tuning/' './results/black-box-tuning/'`
# Glue eco2ai with `python postprocessing/scripts/collate_blackbox_eco2ai_stats.py './results_blackbox_tuning/' './results/black-box-tuning/'`

################################################################################
# 3. first principles experiments
################################################################################
# Same procedure as ground-truth experiments, but with no noise addition.

if false; then
    python experiment/analyze.py datasets/firstprinciples \
        -script optimize_model \
        -results results_first_principles_tuning/ \
        -images /lab-share/CHIP-Lacava-e2/Public/guilherme/singularity_images/ \
        -pretrained_dir /lab-share/CHIP-Lacava-e2/Public/guilherme/srbench_pretrained/ \
        -n_trials 30 -job_time_limit 4:00 -fit_time_limit 3600 \
        -q $cpu_q --scale_x --scale_y --slurm \
        -ml $cpu_ml

    python experiment/analyze.py datasets/firstprinciples \
        -script optimize_model \
        -results results_first_principles_tuning/ \
        -images /lab-share/CHIP-Lacava-e2/Public/guilherme/singularity_images/ \
        -pretrained_dir /lab-share/CHIP-Lacava-e2/Public/guilherme/srbench_pretrained/ \
        -n_trials 30 -job_time_limit 4:00 -fit_time_limit 3600 \
        -q $gpu_q --scale_x --scale_y --slurm \
        -ml $gpu_ml
fi;

# Glue them with `python postprocessing/scripts/collate_experiments_results.py './results_first_principles_tuning/' './results/first-principles-tuning/'`