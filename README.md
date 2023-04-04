# DataDrivenAttribution

Unified Framework for Data-Driven Attribution models and algorithms.

There are a number of well established methods for data-driven attribution modeling.
The objective of DataDrivenAttribution.jl is to 

1. Democratize and add Transparancy to the implimentation of data-drien attribution models
2. Provide users with a unified tool to apply various attribution modeling methods

Methods that are supported and planned to be supported
1. Markov-Chain Model
2. Higher Order Marchov-Chain Models
3. Shapley Model
4. Logistic (planned)
5. LSTM (planned)

 # What is Attributions Modeling

"Attribution is the process of identifying a set of user actions (“events”) across screens and touch points that
contribute in some manner to a desired outcome, and then assigning value to each of these events" - IAB DIGITAL ATTRIBUTION PRIMER 2.0

# Install Dev Version

using Pkg
Pkg.add(url = "https://github.com/bdshaff/DataDrivenAttribution.jl")