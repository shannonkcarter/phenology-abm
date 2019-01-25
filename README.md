# phenology-abm
agent-based model to measure effects of phenological shifts on competitive interactions

QUESTION: How do shifts in phenological synchrony and mean affect competitive outcomes across a range of ecological contexts?

SYSTEM: Agent-based model developed in NetLogo with 2 consumer populations competing for a shared resource

METHODS: 

Entities:
1) 'turtles' = consumers-- each has a size and age. 2 breeds of turtles
2) 'patches' = resource-- generates over time and gets depleted by turtles and background senescence
3) 'global variables' = mean and variation of hatching time for each breed, strength of aysmmetric competition, density of each breed

State variables: 
1) individual hatching time
2) size (all individuals start the same but change with rate of consumption)
3) status (unhatched, active, dead, metamorphosed)
4) location

Process overview:
1) resource starts generating before turtles hatch and is depleted by turtle grazing and background senescence
2) turtles move-- random direction, 1 step per tick to introduce stochasticity
3) turtles eat-- a) feeding radius scales to turtle size b) max meal size scales to size c) compete with turtles on the same patch d) symmetry of competition (global variable) determines feeding order (random -> fully size-ranked)

RESULTS: various ways. data collection and analysis are ongoing.
