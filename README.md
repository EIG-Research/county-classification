<h1>County Locale Classification</h1>

This repository includes  the data code to classify all U.S. counties by six distinct categories: rural, small town, suburban, small urban, medium-sized urban, and large urban.

Contact August Benzow with any questions at august@eig.org.

---

<h2>Data sources</h2>

<h3>Urban-rural definitions</h3>

The National Center for Education Statistics (NCES) [Locale Classifications](https://nces.ed.gov/programs/edge/Geographic/LocaleBoundaries) are the main source used to sort counties on the urban-rural spectrum. This framework is based on definitions of urban areas published by the Census Bureau and provides a more granular categorization of counties than a simple binary of urban and rural.

<h3>Block Groups, Places, Counties, and Metropolitan Areas</h3>

Census 2020 block groups are joined with 2018-2022 American Community Survey population data and then intersected with a shapefile of NCES Locale Classifications. This intersected dataset is then summed up to the county level to determine the share of each county’s population that falls within a particular locale. Counties are additionally intersected with a shapefile of Census places and metropolitan areas. 

---

<h2>Methodology</h2>

Counties are categorized along the urban-rural spectrum using the following criteria:

<h4>Large urban counties</h4>

- Contain the center of a large city (a population of 250,000 or higher). Cook County, Illinois, for example, contains the population center of Chicago.
- Also includes counties where 100 percent of the population resides in a large city, even if they do not contain the city’s center (e.g., Bronx County, New York).

<h4>Mid-sized urban counties</h4>

- Contains the center of a mid-sized city (population of 100,000-250,000). 
- Located within a metropolitan area that lacks a large city. For instance, Washington County, Oregon, includes Hillsboro, a mid-sized city often considered a suburb of Portland.

<h4>Small urban counties</h4>

- Contain the center of a small city (population of 50,000–100,000) or have an urban/suburban population exceeding 50,000
- Inside a metropolitan area without a large or mid-sized city or non-metropolitan.

<h4>Suburban counties</h4>

- More than 50 percent of the county’s population lives in a suburban or urban area of any size or the urban/suburban population exceeds 50,000.
- Must be part of a metropolitan area with a large or mid-sized city but cannot contain the center of such a city.

<h4>Small-town counties</h4>

- Urban/suburban population is less than 50,000 and constitutes less than 50 percent of the total population. Counties with small urban areas are not classified as small-town.
- Less than 50 percent of the population lives in rural areas, or 50–75 percent of the population lives in rural areas with a total county population exceeding 50,000.

<h4>Rural counties</h4>

- At least 75 percent of the population lives in rural areas, or at least 50 percent of the population lives in rural areas with a total county population below 50,000.

<h2>Github structure</h2>

Note: you will need to install and configure [Git Large File Storage](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage) if you have not done so already in order to access the shapefiles (data/shapefiles.zip), as well as tract classification data (tracts classification/EDGE_Locale19_US/EDGE_Locale19_US.zip)

Code:
<ol>
<li>Dataset wrangling</li>
<ol><li>CSVs Cleaning Script (cleans raw CSV files)</li>
<li>Shapefile Cleaning Script (cleans up raw shapefiles)</li></ol>
<li>Locale County Classification</li>
<ol><li>Classifies counties based on the above definitions.</li></ol>
</ol>
