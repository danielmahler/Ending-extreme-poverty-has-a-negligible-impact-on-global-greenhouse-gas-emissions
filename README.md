# Ending extreme poverty has a negligible impact on global greenhouse gas emissions

This repository includes replication code, data sets, and figures from the paper "[Ending extreme poverty has a negligible impact on global greenhouse gas emissions](https://documents1.worldbank.org/curated/en/099557002242323911/pdf/IDU0bbf17510061a9045530b57a0ccaba7a1dc79.pdf)" by [Phillip Wollburg](https://www.worldbank.org/en/about/people/p/philip-randolph-wollburg), [Stephane Hallegatte](https://www.worldbank.org/en/about/people/s/stephane-hallegatte), and [Daniel Gerszon Mahler](https://sites.google.com/view/danielmahler/). You can contact us at shallegatte\@worldbank.org, pwollburg\@worldbank.org, and dmahler\@worldbank.org.

The following explains the content of each of the folders in the repository.

## 1. Input data

This folder contains the raw input data we use as a starting point for our analysis.

## 2. Intermediate data

This folder contains data files created through our data processing that do not yet contain our final results. Several of the files are cleaned versions of the input data.

## 3. Output data

This folder contains the data files used to produce our main results. For size reasons, they are split into several files. The files contain modeled GDP or greenhouses gas emissions. The files have in common five identifier variables:

-   `code`: Country code (or, where applicable, "World")

-   `year`: Year

-   `povertyline`: Poverty line in USD/day in 2017 PPP (\$2.15, \$3.65, \$6.85)

-   `passthroughscenario`: Passthrough rate scenario of growth from GDP to consumption (low, base, high)

-   `ginichange`: Gini change scenario (negative, base, positive)

Next they contain different variables that follow a similar syntax.

-   The variable names start with `gdppc`, `gdpgrowthpc`, `ghgincrease`, or `ghgnenergy`, reflecting whether the variable captures information related to GDP per capita (2017 USD PPP), GDP growth per capita (%), the increase in greenhouse gases needed to alleviate poverty (tCO2e), or energy greenhouse gases (tCO2e).

The variables names proceed with the following information:

-   *Growth scenario indicator*, which takes the value `spa`, `snr`, `sgp`, or `sia`.

    -   `spa` indicates the **s**cenario of **p**overty-**a**lleviation

    -   `snr` indicates the **s**cenario of **n**o-poverty-**r**eduction

    -   `sgp` indicates the **s**cenario of **g**rowth-**p**rojection (projections extrapolating current growth forecasts to 2050)

    -   `sia` indicates a **s**cenario of **i**mmediate poverty **a**lleviation, whereby poverty is reduced to 3% in 2023

The variables starting with `ghgincrease` or `ghgnenergy` are in addition followed by the following information, in order:

-   Energy efficiency indicator, which takes the value `eba`, `e10`, or `e90`.

    -   `eba` indicates the **e**nergy efficiency in the **ba**seline set-up

    -   `e10` indicates the positive **e**nergy efficiency scenario, where all countries improve energy efficiency at the rates of the **10**th percentile historical best performer

    -   `e90` indicates the negative **e**nergy efficiency scenario, where all countries improve energy efficiency at the rates of the **90**th percentile historical best performer

-   Carbon efficiency indicator, which takes the value `cba`, `c10`, or `c90`.

    -   `cba` indicates the **c**arbon efficiency in the **ba**seline set-up

    -   `c10` indicates the positive **c**arbon efficiency scenario, where all countries improve carbon efficiency at the rates of the **10**th percentile historical best performer

    -   `c90` indicates the negative **c**arbon efficiency scenario, where all countries improve carbon efficiency at the rates of the **90**th percentile historical best performer

-   Population projection indicator, which takes the value `pba`, `plo`, `phi`, or `pcl`

    -   `pba` indicates the **p**opulation projections in the **ba**seline set-up

    -   `plo` indicates the **p**opulation projections using the World Population Prospects' **lo**w variant

    -   `phi` indicates the **p**opulation projections using the World Population Prospects' **hi**gh variant

    -   `pcl` indicates **p**opulation projections **c**a**l**culated while accounting for the impact of additional economic growth on fertility rates

The baseline results are in the variable called `ghgincrease_spa_cba_eba_pba` while subsetting `ginichange=="base"` and `passthroughscenario=="base"`.

## 4. Code

This folder contains all the code necessary to reproduce our results.

1.  Scripts starting with 1 prepare the main input data

    -   `1a-IncomeConsumptionConversion.do`*:* Explores how to convert income distributions to consumption distributions

    -   `1b-Poverty.do`*:* Prepares the 2022 income and consumption distributions needed for the poverty analysis

    -   `1c-Population.do`*:* Prepares the population data

    -   `1d-GDP.do`*:* Prepares the growth data

    -   `1e-GHG.do`*:* Prepares the GHG data

    -   `1f-Energy.do`*:* Prepares the energy data

2.  Scripts starting with 2 calculate the growth needed to alleviate poverty

    -   `2a-GrowthPoverty.do`*:* Calculates passthrough rates using a random slope model

    -   `2b-GrowthNeed.do`*:* Calculates the growth needed to alleviate poverty under various scenarios

    -   `2c-PlausibleInequalityChanges.do`*:* Calculates plausible Gini changes based on historical data

    -   `2d-Map.R`*:* Produces a map indicating whether countries have achieved the poverty target at a given line

3.  Scripts starting with 3 calculate the greenhouse gases associated with economic growth

    -   `3a-ExploringRelationships.do`*:* Creates scatter plots between GDP, energy, and GHG

    -   `3b-EnergyGDP.do`*:* Models the relationship between energy/capita and GDP/capita

    -   `3c-GHGEnergy.do`*:* Models the relationship between GHG/capita from energy and energy/capita

4.  Scripts starting with 4 calculate the greenhouse gases needed to alleviate poverty

    -   `4a-PovertyGHG.do`*:* Calculates the GHG necessary to alleviate poverty

    -   `4b-PovertyGHG_Targets.do`*:* Calculates the GHG necessary to alleviate poverty under different poverty rate or GDP targets

    -   `4c-PovertyGHG_Uncertainty.do`*: C*alculates the GHG necessary to alleviate poverty while accounting for the uncertainty implicit in our random-slope regressions

    -   `4d-PovertyGHG_GiniScenarios.do`*:* Calculates the GHG necessary to alleviate poverty under changing-inequality scenarios

5.  Scripts starting with 5 expres the results in various manners

    -   `5a-MainFigures.do`*:* Produces the figures with our main results

    -   `5b-AdditionalResults.do`*:* Calculates other results referenced in the the paper

    -   `5c-Scenarios.do`*:* Calculates the GHG necessary to eliminate poverty under various scenarios

    -   `5d-RobustnessChecks.do`*:* Produces some robustness checks

6.  Scripts starting with 6 generate figures used to clarify modeling approach

    -   `6a-BeeswarmExmaples.R`*:* Produces the beeswarm plot

    -   `6b-ScenarioIllustration.do`*:* Produces illustrative figures of the poverty-alleviation and no-poverty-reduction scenarios

## 5. Figures

This folder contains the figures, named according to the figure number of the published version of the paper. It also includes an .xlsx called "SourceData" which contains the data from each figure.

## Note on replicability

The .do-file `1d-GDP.do` loads GDP data from the World Development Indicators through the line `wbopendata, indicator(NY.GDP.PCAP.PP.KD) long clear`. For the published version of the paper, we used the data in WDI available as of 2022.12.19. To replicate the results of the paper, rather than running this .do-file, use the output file `02-Intermediatedata\GDP.dta` in the repository for the subsequent analysis. If `1d-GDP.do` is run, most results will deviate a little from the paper due to updated GDP data.
