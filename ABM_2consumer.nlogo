;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GLOBALS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; GLOBAL VARIABLES
globals
[
  ;; fish related
  n-meta-fishes      ; number of fish that achieve metamorphosis (calculated at the end of the simulation)
  n-dead-fishes      ; number of fish that starve before achieving metamorphosis
  biom-fishes        ; sum size of all metamorphed fishes
  mean-size-fishes   ; mean size of all individual fish that reach metamorphosis (i.e., biomass/n-meta)

  ;; dfly related
  n-meta-dflies      ; number of dflies that achieve metamorphosis (calculated at the end of the simulation)
  n-dead-dflies      ; number of dflies that starve before achieving metamorphosis
  biom-dflies        ; sum size of all metamorphed dflies
  mean-size-dflies   ; mean size of all individual dflies that reach metamorphosis (i.e., biomass/n-meta)

  ;; community related
  n-meta-total       ; number of turtles that achieve metamorphosis (calculated at the end of the simulation)
  biom-total         ; sum size of all metamorphed turtles
]

;; TWO BREEDS ACT AS RESOURCE COMPETITIORS AND CAN BE CONTROLLED SEPARATLEY
breed [fishes fish]
breed [dflies dfly]

;; FISHES AND DFLIES HAVE MOST THINGS IN COMMON, BUT NEED TO BE CONTROLLED SEPARATELY
fishes-own
[
  hatch-tick         ; each turtle has a time they become hatch/enter environment - this can have the same name across breeds, but breed timing is controlled by diff params
  meals              ; a list of how many patches it eats each time step. used for growth rate and starvation. can have the same name, because meals is only used internally
  size-list-fish     ; a running list of the size of the turtle at each time step. separated by breeds so we can separate in R later.
  recent-growth-fish ; an average of growth over the last 10 time steps. Separated by breeds bc size-list is.
  consump-list-fish  ; a list of how many patches the turtle has eaten recently-- used to determine starvation. Separated by breeds bc size-list is.
  meta-fish?         ; 0/1 reporter of whether the turtle survived. saves as a list in BS, i.e., [0 0 0 1 1 1 0 0 1...]
  recent-sizes-fish  ; sublist of size-list used to calculate recent growth rate. Separated by breeds bc size-list is.
  ;maintenance-cost
]

dflies-own           ; unclear if each of these has to have a -dfly -fish tag. will find out
[
  hatch-tick         ; each turtle has a time they become hatch/enter environment
  meals              ; a list of how many patches it eats each time step. used for growth rate and starvation
  size-list-dfly     ; a running list of the size of the turtle at each time step
  recent-growth-dfly ; an average of growth over the last 10 time steps
  consump-list-dfly  ; a list of how many patches the turtle has eaten recently-- used to determine starvation
  meta-dfly?         ; 0/1 reporter of whether the turtle survived
  recent-sizes-dfly  ; sublist of size-list used to calculate recent growth rate
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;; SETUP PROCEDURE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  ca                                  ; clear, needed for every set-up procedure

  ;; CREATE FISHES
  create-fishes n-fishes              ; slider on interface
  [
    set size 0                        ; start with size 0 so i can tell the hatch tick from [size-list]. i.e., tick where size goes from 0 to 1.
    set color gray                    ; gray indicates not yet hatched-- can't move or be cannibalized
    setxy random-xcor random-ycor     ; position actually doesn't matter at all, but it's easier to see things if they're scattered
    set shape "fish"                  ; this is where the biology comes in
    set hatch-tick round (random-normal mean-hatch-fishes var-hatch-fishes)  ; can control mean and variance of fish hatch time- sliders on interface
    set meals [10 10 10 10 10 10 10 10 10]  ; initializes an empty list to store meal data in. start with values so that they don't starve out the gate
    set size-list-fish [0 0 0 0 0]          ; have to start with size info so the growth calculations have values to work with
    set recent-growth-fish 0                ; a dynamic value that determines whether metamorphosis happens
  ]

    ;; CREATE DFLIES
  create-dflies n-dflies              ; slider on interface
  [
    set size 0                        ; start with size 0 so i can tell the hatch tick from [size-list]. i.e., tick where size goes from 0 to 1.
    set color gray                    ; gray indicates not yet hatched-- can't move or be cannibalized
    setxy random-xcor random-ycor     ; position actually doesn't matter at all, but it's easier to see things if they're scattered
    set shape "dfly"                  ; this is where the biology comes in
    set hatch-tick round (random-normal mean-hatch-dflies var-hatch-dflies)  ; can control mean and variance of fish hatch time- sliders on interface
    set meals [10 10 10 10 10 10 10 10 10]  ; initializes an empty list to store meal data in. start with values so that they don't starve out the gate
    set size-list-dfly [0 0 0 0 0]          ; have to start with size info so the growth calculations have values to work with
    set recent-growth-dfly 0                ; a dynamic value that determines whether metamorphosis happens
  ]

  ;; MAKE LANDSCAPE
  ask patches           ; can say n-of x patches if wanting less resource
  [set pcolor brown]    ; brown patches = unsprouted, can grow grass. black = dead/eaten, cannot grow grass

  reset-ticks           ; resets the clock, needed for every set-up procedure

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;; GO PROCEDURE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go

    ;; GRASS GROWTH AND DEATH
    grass-production                ; background grass growth, controlled by procedure below

    ;; TURTLES MOVE AND EAT
ask fishes
[
  set size-list-fish lput (size) size-list-fish   ; each tick, they add their size to the list. fish and dflies need separate lists so we can id in R
    ;ifelse asym-slope-fishes = 0
    ;[set maintenance-cost 2]
    ;[set maintenance-cost  0.5 * size ^ 0.75 ]
]

ask dflies
[
  set size-list-dfly lput (size) size-list-dfly
]

    ask turtles
     [
      if ticks = hatch-tick [set size 1]                           ; first time where size = 1 is hatch tick in BS output data
      if ticks > hatch-tick and color != red and color != yellow   ; once you're hatched but before you're dead (red) or metamorphed (yellow), you start doing stuff
      [                                                            ; if you've eaten enough to not starve, keep going. else, die.
        ifelse (item 0 meals + item 1 meals + item 2 meals + item 3 meals + item 4 meals + item 5 meals + item 6 meals + item 7 meals + item 8 meals) > 0.5 * size ^ 0.75  ; 0.75 scaling from BMR literature
        [
          if breed = fishes [set color green]
          if breed = dflies [set color blue]   ; blue = alive and kicking
          eat-grass        ; turtle specific procedure controlled below. may want to separate by breeds...
          metamorph-fish   ; separate procedures, but may or may not change the criteria.
          metamorph-dfly
        ]
        ; death procedure if they don't eat enough
        [
          set color red                         ; red = dead
          stamp                                 ; useful to see survival/death in interface.
          if breed = fishes [set meta-fish? 0]  ; report that they didn't metamorphose
          if breed = dflies [set meta-dfly? 0]
        ]
      ]
     ]


    tick                                                       ; all of the above happens each time step. 'tick' = new time step started
    if ticks = 250 [stop]                                      ; this end point comes after all action-- just makes it easier to work with data in R if each run is the same length

    ;; CALCULATE RESPONSE VARIABLES

    ; fish related
    set n-meta-fishes count fishes with [color = yellow]             ; at this point, set the number of metamorphs to the number of yellow fish
    set n-dead-fishes count fishes with [color = red]                ; at this point, set the number of dead fish to the number of red fish
    set biom-fishes sum [size] of fishes with [color = yellow]       ; biomass = biomass export-- only counting those that survive and advance to next stage
    ;set mean-size-fishes mean [size] of fishes with [color = yellow] ; throws an error in interface, but works in behaviorspace. I thought these calculated only at the end...

    ; dfly related
    set n-meta-dflies count dflies with [color = yellow]             ; at this point, set the number of metamorphs to the number of yellow fish
    set n-dead-dflies count dflies with [color = red]                ; at this point, set the number of dead fish to the number of red fish
    set biom-dflies sum [size] of dflies with [color = yellow]       ; biomass = biomass export-- only counting those that survive and advance to next stage
    ;set mean-size-dflies mean [size] of dflies with [color = yellow] ; throws an error in interface, but works in behaviorspace. I thought these calculated only at the end...

    ; community related
    set n-meta-total count turtles with [color = yellow]
    set biom-total sum [size] of turtles with [color = yellow]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;; GRASS GROWTH & DEATH PROCEDURE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; BACKGROUND GRASS GROWTH AND DEATH
to grass-production

  ;; GROWTH- X% GROSS GROWTH RATE PER TICK (controlled by slider)
  if ticks > sprout-tick                  ; makes a delay on grass growth-- can adjust for now, make sure turtles don't beat resource
  [
    ask patches
    [
      if pcolor = brown                   ; only brown patches can sprout; don't want patches regenerating
      [
        if random 100 < grass-grow-rate   ; ggr% of brown patches sprout each tick
        [set pcolor 52]                   ; sprouted = can be eaten by turtles = green. make it dark green so it's distinguishable from metamorphs
      ]
    ]
  ]

  ;; DEATH- Y% GROSS DEATH RATE PER TICK (controlled by slider)
  ask patches
  [
    if pcolor = 52                      ; only green patches can die
    [
      if random 100 < grass-death-rate  ; gdr% of green patches die each tick
      [set pcolor black]                ; black patches do not regenerate
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;; EAT-GRASS PROCEDURE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; TURTLE CONSUMPTION PROCEDURE
to eat-grass

  ;; WHICH AND HOW MANY PATCHES CAN I EAT?
  if breed = fishes
  [
  let max-meal                                                 ; max-meal is the maximum number of patches an individual *could* eat. not always realized.
  (asym-slope-fishes * size + 3)
  ;(
  ;  min                                                        ; minimum between max they could eat and number of patches available
  ;  (
  ;    list                                                     ; have to make a list otherwise it will call for too many agents.
  ;      (asym-slope-fishes * size + (5 - 5 * asym-slope-fishes))   ; max-meal = slope*size + intercept. put intercept in terms of slope so that they're controlled by the same variable. easier for BS
  ;      (0.2 * count patches with [pcolor = 52])               ; when resources are running low, a single turtle (i.e., the one randomly assigned to eat first) can't eat all the remaining patches
  ;    )
  ;  )

  ;; LOCAL VARIABLES FOR FEEDING GAINS
  let growth-this-tick 0                        ; at the start of each tick, they haven't grown that tick

  ;; EAT PATCHES
  ask n-of max-meal patches                     ; they choose max-meal number of patches...
  [
    if pcolor = 52                              ; ... but only get gains from those that are green
    [
    set pcolor black                                               ; eaten patches turn black and don't regenerate
    set growth-this-tick growth-this-tick + growth-per-patch       ; g-p-p can be used to calculate patches needed to metamorph, i.e., with size 1 -> 10 and 0.1, need to eat 100 patches
    ]
  ]

  set size size + growth-this-tick                                 ; grow proportional to the number of patches they ate that tick
  set meals fput round (growth-this-tick / growth-per-patch) meals ; meals list is used to calculate starvation. this adds n-patches eaten to that list
  set recent-sizes-fish sublist size-list-fish ((length size-list-fish) - 5) (length size-list-fish)  ; have to make a sublist here to isolate the last values added to the list, i.e., recent size
  let size-ratio-fish max list last recent-sizes-fish 0.001 / max list item 0 recent-sizes-fish 0.001 ; the max list 0.001 elements prevent us from dividing by 0. basically = size(t)/size(t-5)
  set recent-growth-fish(log size-ratio-fish 10 / 5)
  ]


  if breed = dflies
  [
  let max-meal                                                 ; max-meal is the maximum number of patches an individual *could* eat. not always realized.
  (4 + size * asym-slope-dflies)
  ;(
  ;  min                                                        ; minimum between max they could eat and number of patches available
  ;  (
  ;    list                                                     ; have to make a list otherwise it will call for too many agents.
  ;      (1.5 * asym-slope-dflies * size + (5 - 5 * asym-slope-dflies))   ; max-meal = slope*size + intercept. put intercept in terms of slope so that they're controlled by the same variable. easier for BS
  ;      (0.2 * count patches with [pcolor = 52])               ; when resources are running low, a single turtle (i.e., the one randomly assigned to eat first) can't eat all the remaining patches
  ;    )
  ;  )

  ;; LOCAL VARIABLES FOR FEEDING GAINS
  let growth-this-tick 0                        ; at the start of each tick, they haven't grown that tick

  ;; EAT PATCHES
  ask n-of max-meal patches                     ; they choose max-meal number of patches...
  [
    if pcolor = 52                              ; ... but only get gains from those that are green
    [
    set pcolor black                                               ; eaten patches turn black and don't regenerate
    set growth-this-tick growth-this-tick + growth-per-patch       ; g-p-p can be used to calculate patches needed to metamorph, i.e., with size 1 -> 10 and 0.1, need to eat 100 patches
    ]
  ]

  set size size + growth-this-tick                                 ; grow proportional to the number of patches they ate that tick
  set meals fput round (growth-this-tick / growth-per-patch) meals ; meals list is used to calculate starvation. this adds n-patches eaten to that list
  set recent-sizes-dfly sublist size-list-dfly ((length size-list-dfly) - 5) (length size-list-dfly)  ; have to make a sublist here to isolate the last values added to the list, i.e., recent size
  let size-ratio-dfly max list last recent-sizes-dfly 0.001 / max list item 0 recent-sizes-dfly 0.001 ; the max list 0.001 elements prevent us from dividing by 0. basically = size(t)/size(t-5)
  set recent-growth-dfly(log size-ratio-dfly 10 / 5)
  ]


  ;; SET A LABEL FOR INTERFACE DIAGNOSTICS
  ifelse show-label?
  [set label round(size)] ; / (ticks - hatch-tick))]  ; can be useful to show size, size-list, age, hatch tick, etc. when troubleshooting
  [set label ""]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;; METAMORPHOSIS PROCEDURE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; METAMORPH PROCEDURE
; seaparte into different breeds to keep separate tallies and so that criteria can be different
to metamorph-fish
  ; each time step, they think about metamorphosing, but only do so if they meet this criteria:
  ; mortality*minimumsize / (mortality - rgr)
  if breed = fishes and size > (0.102 / (0.0170000001 - recent-growth-fish)) and size > 6 and recent-growth-fish < 0.017 ; have the .000001 there so that the denominator won't ever be 0
  [
    set color yellow                   ; ones that metamorph turn yellow
    set meta-fish? 1                   ; turtles-own variable to tell us whether they metamporphed
    stamp                              ; useful for visualizing/troubleshooting
  ]
end

to metamorph-dfly
  ; each time step, they think about metamorphosing, but only do so if they meet this criteria:
  ; mortality*minimumsize / (mortality - rgr)
  if breed = dflies and size > (0.102 / (0.0170000001 - recent-growth-dfly)) and size > 6 and recent-growth-dfly < 0.017 ; have the .000001 there so that the denominator won't ever be 0
  [
    set color yellow                   ; ones that metamorph turn yellow
    set meta-dfly? 1                   ; turtles-own variable to tell us whether they metamporphed
    stamp                              ; useful for visualizing/troubleshooting
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
290
11
877
599
-1
-1
5.85
1
10
1
1
1
0
1
1
1
-49
49
-49
49
1
1
1
ticks
30.0

BUTTON
89
17
144
50
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
146
16
201
49
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
903
10
1047
43
grass-grow-rate
grass-grow-rate
0.0
10
6.0
1
1
NIL
HORIZONTAL

PLOT
11
450
285
598
Populations
Time
Pop
0.0
100.0
0.0
100.0
true
true
"set-plot-y-range 0 n-fishes" ""
PENS
"grass" 1.0 0 -10899396 true "" "plot count patches with [pcolor = 52] / 20"
"fish" 1.0 0 -955883 true "" "plot count fishes with [color = blue]"
"dflies" 1.0 0 -13345367 true "" "plot count dflies with [color = blue]"

SLIDER
146
52
282
85
n-fishes
n-fishes
0
200
80.0
1
1
NIL
HORIZONTAL

SLIDER
151
123
286
156
var-hatch-fishes
var-hatch-fishes
0
30
30.0
1
1
NIL
HORIZONTAL

SLIDER
903
44
1047
77
grass-death-rate
grass-death-rate
0
10
0.0
1
1
NIL
HORIZONTAL

SLIDER
904
78
1046
111
sprout-tick
sprout-tick
0
100
0.0
5
1
NIL
HORIZONTAL

SLIDER
904
112
1047
145
growth-per-patch
growth-per-patch
0
0.5
0.05
0.01
1
NIL
HORIZONTAL

PLOT
905
194
1192
344
turtle outcomes
Time
Population
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"fish metas" 1.0 0 -955883 true "" "plot n-meta-fishes"
"dfly metas" 1.0 0 -13345367 true "" "plot n-meta-dflies"

MONITOR
905
147
1048
192
grass patches
count patches with [pcolor = 52]
0
1
11

PLOT
12
297
285
447
hatching synchrony
hatch-tick
frequency
0.0
100.0
0.0
10.0
true
true
"" ""
PENS
"fishes" 1.0 1 -955883 true "" "histogram [hatch-tick] of fishes"
"dflies" 1.0 1 -13345367 true "" "histogram [hatch-tick] of dflies"

SWITCH
906
346
1032
379
show-label?
show-label?
1
1
-1000

SLIDER
149
86
282
119
mean-hatch-fishes
mean-hatch-fishes
0
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
149
159
284
192
asym-slope-fishes
asym-slope-fishes
0
1
1.0
0.1
1
NIL
HORIZONTAL

PLOT
923
436
1123
586
size distribution of turtles
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"fish" 0.2 1 -955883 true "" "histogram [size] of fishes"
"dfly" 0.2 1 -13345367 true "" "histogram [size] of dflies"

SLIDER
4
48
143
81
n-dflies
n-dflies
0
200
0.0
1
1
NIL
HORIZONTAL

SLIDER
6
84
143
117
mean-hatch-dflies
mean-hatch-dflies
0
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
6
121
145
154
var-hatch-dflies
var-hatch-dflies
0
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
5
157
144
190
asym-slope-dflies
asym-slope-dflies
0
1
0.5
0.1
1
NIL
HORIZONTAL

MONITOR
164
213
253
258
NIL
n-meta-fishes
0
1
11

MONITOR
41
229
127
274
NIL
n-meta-dflies
0
1
11

@#$#@#$#@
;;; OVERVIEW ;;;

1. PURPOSE

Q: Under what ecological conditions is phenological synchrony important for consumer-resource interactions?

Here, we look at consumer-resource dynamics under different manipulations of consumer phenological synchrony. We manipulate the synchrony (i.e., individual variation) in hatching timing and the size-dependent per capita effects (i.e., the relationship between individual size and resource consumption).

H: Synchrony should be most important when asymmetric competition is high and density is high. Synchrony should be less important when individuals of different sizes are more similar. The particulars of this relationship, particularly what happens when changing multiple attributes at once, are difficult to intuit.

2. ENTITIES, STATE VARIABLES, AND SCALES

- Turtles = consumers—have size & age
- Patches = resource— 9801 patches that start brown (unsprouted) and grow over time. Each time step, 6% of brown patches turn green, indicating they're available for consumption. Green patches get consumed by turtles and turn black. Black/consumed patches cannot regenerate. 
- Global variables
- Synchrony of turtle arrival (scale with several levels)
- Mean date of turtle arrival (find a appropriate level and keep it there)
- Asymmetric competition (scale of different advantages of larger individuals)
- Density of turtles
- Each time step ~= 1 day
- Currently, each turtles advances to next phenological stage if they reach size >=10 and die by a starvation mechanism, but alternatively could make fate determined after a set time interval.

3. PROCESS, OVERVIEW, AND SCHEDULING

- Resource is generated before turtles arrive and is depleted as turtles land on it and eat. Background senescence of resource = x patches die per time step (this can be turned off and doesn't change things too much)
- Turtles eat and grow
- Competition with turtles on the same patch
- Symmetry of competition determines how individual size affects feeding order and/or feeding amount and/or growth per unit food


;;; DESIGN CONCEPTS ;;;

4. DESIGN CONCEPTS (p 41, table 3.1)

- Basic principles—consumer/resource model with intraspecific competition
- When turtles eat from a patch, they turn it black (empty) and grow a fixed amount in size
- Competition—only 1 turtle can eat a patch per year. Larger turtles have a better chance of eating (in asymmetric competition conditions) and eat more
- Emergent outcomes— relative importance of numerical vs. per capita effects. Per capita effects of consumers on resource might outweigh numerical effects when synchrony is low and asymmetric competition is high
- Adaptation— none 
- Objectives— survive to reproductive period and eat as much as possible 
- Learning— none
- Prediction— none
- Sensing— none
- Interaction— indirect interaction through resource
- Stochasticity— none necessary, but may be incorporated into some processes (i.e., movement)
- Collectives— none
- Observations— number of turtles, average and range turtle size, size/fitness/survival of early vs. late arriving turtles. 


;;; DETAILS ;;;

5. INITIALIZATION
- Initial turtle size = 1
- Initial turtle location = random
- Initial n-turt = 50
- Initial world size = 500
- Turtle synchrony— turtles created all at once or spread out
- Turtle mean— turtles come at start of resource or before/after

6. INPUT DATA — none 

7. SUBMODELS
- Feeding— includes competition
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dfly
true
0
Line -7500403 true 135 150 75 150
Line -7500403 true 75 150 45 105
Line -7500403 true 75 165 45 165
Line -7500403 true 120 150 75 165
Line -7500403 true 120 165 75 195
Line -7500403 true 75 195 30 195
Line -7500403 true 210 165 165 150
Line -7500403 true 210 165 240 165
Line -7500403 true 180 150 225 150
Line -7500403 true 225 150 255 105
Line -7500403 true 180 165 210 210
Line -7500403 true 210 210 255 210
Polygon -7500403 true true 120 150 105 135 120 120 120 120 135 105 150 105 165 105 180 120 180 120 195 135 180 150 180 150 180 165 165 180 165 195 165 210 165 255 150 270 135 255 135 180 120 165 120 150
Polygon -7500403 true true 135 195 120 225 135 255
Polygon -7500403 true true 165 195 180 225 165 255

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

monster
false
0
Polygon -7500403 true true 75 150 90 195 210 195 225 150 255 120 255 45 180 0 120 0 45 45 45 120
Circle -16777216 true false 165 60 60
Circle -16777216 true false 75 60 60
Polygon -7500403 true true 225 150 285 195 285 285 255 300 255 210 180 165
Polygon -7500403 true true 75 150 15 195 15 285 45 300 45 210 120 165
Polygon -7500403 true true 210 210 225 285 195 285 165 165
Polygon -7500403 true true 90 210 75 285 105 285 135 165
Rectangle -7500403 true true 135 165 165 270

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

rabbit
false
0
Circle -7500403 true true 76 150 148
Polygon -7500403 true true 176 164 222 113 238 56 230 0 193 38 176 91
Polygon -7500403 true true 124 164 78 113 62 56 70 0 107 38 124 91

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="test 3" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-cannibalized</metric>
    <metric>n-starved</metric>
    <metric>n-metamorphs</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="10"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="5Sync_2Cann" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-starved</metric>
    <metric>n-cannibalized</metric>
    <metric>n-dead</metric>
    <metric>n-metamorphs</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <steppedValueSet variable="var-hatch" first="0" step="5" last="30"/>
    <enumeratedValueSet variable="number">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="10"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="testing" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-meals?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="doesthisworkpt4" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="doesthisworkpt5" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="doesthisworkpt6" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="fulltest" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="0"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="fulltest2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="fulltest3" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>n-starved</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="bigtest_4sync_2growth_3rep" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sync_density1" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="40"/>
      <value value="80"/>
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test7" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <metric>[size-list] of turtles</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="1"/>
      <value value="3"/>
      <value value="5"/>
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="40"/>
      <value value="80"/>
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test8" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-metamorphs</metric>
    <enumeratedValueSet variable="mean-hatch">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch">
      <value value="1"/>
      <value value="3"/>
      <value value="5"/>
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number">
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
      <value value="100"/>
      <value value="120"/>
      <value value="140"/>
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cann-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test9" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-meta-dflies</metric>
    <metric>n-meta-fishes</metric>
    <metric>[fish-size-list] of fishes</metric>
    <metric>[dfly-size-list] of dflies</metric>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-fishes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch-dflies">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-hatch-dflies">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-dflies">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch-fishes">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-hatch-fishes">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test10" repetitions="2" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-meta-dflies</metric>
    <metric>n-meta-fishes</metric>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-fishes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch-dflies">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-hatch-dflies">
      <value value="10"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-dflies">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch-fishes">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-hatch-fishes">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="2sp_mean&amp;sync_pop" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-meta-dflies</metric>
    <metric>n-meta-fishes</metric>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-fishes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch-dflies">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="mean-hatch-dflies" first="10" step="5" last="40"/>
    <enumeratedValueSet variable="n-dflies">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch-fishes">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="2sp_mean&amp;sync_individual" repetitions="4" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-meta-dflies</metric>
    <metric>n-meta-fishes</metric>
    <metric>[dfly-size-list] of dflies</metric>
    <metric>[fish-size-list] of fishes</metric>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-fishes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch-dflies">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-hatch-dflies">
      <value value="10"/>
      <value value="15"/>
      <value value="25"/>
      <value value="35"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-dflies">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="var-hatch-fishes">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="1Consumer" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-meta-fishes</metric>
    <metric>n-dead-fishes</metric>
    <metric>mean-size-fishes</metric>
    <metric>[meta-fish?] of fishes</metric>
    <metric>[size-list-fish] of fishes</metric>
    <metric>biom-fishes</metric>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-dflies">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-fishes">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="var-hatch-fishes" first="0" step="3" last="30"/>
    <enumeratedValueSet variable="var-hatch-dflies">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-hatch-fishes">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-hatch-dflies">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="asym-slope-dflies">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="asym-slope-fishes">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="2Consumer" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>n-meta-fishes</metric>
    <metric>n-meta-dflies</metric>
    <metric>n-dead-fishes</metric>
    <metric>n-dead-dflies</metric>
    <metric>n-meta-total</metric>
    <metric>[meta-fish?] of fishes</metric>
    <metric>[meta-dfly?] of dflies</metric>
    <metric>[size-list-fish] of fishes</metric>
    <metric>[size-list-dfly] of dflies</metric>
    <metric>biom-fishes</metric>
    <metric>biom-dflies</metric>
    <metric>biom-total</metric>
    <enumeratedValueSet variable="show-label?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-dflies">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-fishes">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sprout-tick">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="var-hatch-fishes" first="0" step="3" last="30"/>
    <enumeratedValueSet variable="var-hatch-dflies">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-hatch-fishes">
      <value value="45"/>
      <value value="60"/>
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-hatch-dflies">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="growth-per-patch">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-grow-rate">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-death-rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="asym-slope-dflies">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="asym-slope-fishes">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
