# Advocacy Games

The code for the paper Advocacy Games by Steven Kuhn and Eric Pacuit.

The simulation is written in Julia using the [Agents.jl package](https://juliadynamics.github.io/Agents.jl).  

## Overview

### Main Simulation Files

* advgames.jl: Implementation of the simulation.
* advgames_network.jl: Implementation of the simulation where agents are placed on a network.
* advgames_analysis.jl: Functions used to analyze a run of the simulation.

### Experiment Files

The following notebooks contain the code used to generate the data and figures in the paper.

* advgames_analysis_different_pressures_network.ipynb
* advgames_analysis_different_pressures_population_network.ipynb
* advgames_analysis_different_pressures_population.ipynb
* advgames_analysis_different_pressures.ipynb
* advgames_analysis_experiments.ipynb
* advgames_analysis_payoffs_network.ipynb
* advgames_analysis_payoffs.ipynb
* advgames_init_analysis_network.ipynb
* advgames_initial_conditions.ipynb
* advgames_initial_experiments_network.ipynb 
* advgames_initial_experiments.ipynb
* advgames_simulation_explanation_graphs.ipynb

## Visualization files

The following notebooks contain the code used to generate the visualizations in the paper.   

* visualization_analysis.ipynb
* visualization_init_analysis_network.ipynb
* visualization_popsizes_pressures.ipynb
* visualization_pos_neg_pressures.ipynb
* visualization_simulation_explanation.ipynb
* visualization.ipynb, **Note**: The csv file needed for this visualization is zipped to reduce the size.  To run this notebook, unzip the file `agent_data_init_model_data_init.zip` in the `simulation_explanation` directory.
* visualize_diff_initial_conditions.ipynb
* visualize_diff_payouts.ipynb

