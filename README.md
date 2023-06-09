# DataDrivenAttribution

Data-Driven Attribution models and algorithms

Blog & Documentation @ <https://shafferbendenis.quarto.pub/data-driven-attribution/>

# What is Attributions Modeling

"Attribution is the process of identifying a set of user actions (“events”) across screens and touch points that
contribute in some manner to a desired outcome, and then assigning value to each of these events" - IAB DIGITAL ATTRIBUTION PRIMER 2.0

# Why DataDrivenAttribution.jl
There are a number of well-established methods for data-driven attribution modeling.
The objective of DataDrivenAttribution.jl is to implement and make available a collection of attribution modeling algorithms and tools, all in a unified package.


# WIP Roadmap
Currently implemented and planned methods include
1. Markov-Chain Model
2. Higher Order Markov-Chain Models
3. Shapley Model
4. (Simple) Logistic

(planned)
5. RNNs/LSTMs 
6. Logistic with interactions/regularization + Bayesian
7. Bayesian Markov-Chain


# Install Dev Version: CAUTION

ASSUME EVERYTHING WILL CHANGE
Types, structures, design, interface - at this point of the lifecycle it's safe to assume that nothing about the package will remain the same in the medium to long term.

using Pkg

Pkg.add(url = "https://github.com/bdshaff/DataDrivenAttribution.jl")


# Main functions

## dda_model

## dda_summary

## dda_markov_model

## dda_shapley_model

## dda_logistic_model

## plot_conversion_volume

## plot_rcr