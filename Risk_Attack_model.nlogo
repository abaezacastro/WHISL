extensions [table]
Globals [
  A                        ; Area for wildlife, weighted by quality and domain
  table_landQ              ; table cost-quality
  i                        ; counter
  cost_Y                   ; Cost of production (the same for all sites)
  new_ff                   ; auxiliar variable to define new farmers (used in setup the houses)
  wage                     ; off-farm income [$/hour]
  cost_f                   ; cost of fencing a site [$]
  m                        ; time of fencing a site [time]

;;subjective risk
  alpha                    ;Dynamic Subjective Risk Beliefs parameter
  beta                     ;Dynamic Subjective Risk Beliefs parameter
  delta                    ;Dynamic Subjective Risk Beliefs parameter
  s
;;reporters
tot_cost_production
tot_damage
tot_income
;;Auxiliar
counter
]

breed [farmers farmer]

farmers-own [
  Income                   ; Income
  N_attacks_to_farmer      ; number of attacks a farmer received in a year
  farm                     ; set of patches that belong to a farmer and define the "farm"
  farmed_patches           ; set of patches designated to cultivation in a year
  labor_hunting            ; time designated to kill animals
  Tot_Labor                ; total time available to farming

  attacks_list             ;list to save past attacks for adjusting subjective risk
  count_total_attacks      ;;total number of attacks in a year
  subjective-Risk
]

patches-own [
  Quality                  ; wildlife habitat quality
  Domain                   ; boolean variable to represent the availability of a site for wildlife. If Domain=1 if the site is availalble; if domain < 1 the site is less usitable if D = 0 a fence is there
  Landtype                 ; land use-type. For now only Agriculture and Forest
  Yield_Q                  ; Potential of production per site per year
  labor_AGRO               ; Labor needed to obtain the maximal yield (Yield_Q)
  labor_needed             ; Labor used in each patch including fencing or maitaining it
  EU_NF                    ; Expected utility without fencing needed
  EU_WF                    ; Expected utility of patches with fencing needed
  EU_WF_maint              ; Expected utility of patches that need fence maitainance
  EU                       ; Expected utility final
  decision_fencing         ; Decision made by farmer to fence or not [True or False]
  p_occ                    ; Probablity of occupancy
  N_attacks_here           ; Number of attacks per site per year
  farmer_owner             ; To define the farmer owner of the site
]

to setup
  clear-all
  reset-ticks
  quality_landscape        ;define quality of land
  set cost_Y 0.5             ;need to be parametrized
  set counter 0
  set delta 1.5
  ask patches [
    set Domain 1
    set Quality 1
    set Landtype "F"
    set decision_fencing "NF"
    set farmer_owner 0
  ]
  house_location
  define_farms
  setup-spatially-clustered-network
  landscape_visualization
end



to quality_landscape        ;here we define the quality of the patch for agriculture
      ask patches [
        set Yield_Q 1 + random pxcor
        set labor_AGRO 1
      ]
end

to house_location
  create-farmers round (Number-of-Farmers * 0.1) [
    ; here we can assign the location based on land productivity and density
    move-to one-of patches with [not any? farmers-here]
    set shape "house"
    set size 2
    set Tot_Labor 20 ;;so, to make things simple if a household invest all its labor it will produce all potential crop, assuming not attacks and therefore not fences needed
    set Income 0
    set attacks_list [0 0 0 0 0]
    set count_total_attacks 0
  ]

  set i 0
  loop [
    ask one-of farmers [
    set new_ff one-of patches in-radius distance-btw-households with [not any? farmers-here]
    ]
  create-farmers 1 [
    ; here we assign the location based on land productivity and density

    move-to new_ff

    set shape "house"
    set size 2
    set Tot_Labor 20 ;; set the available labor
    set Income 0
    set attacks_list [0 0 0 0 0]
    set count_total_attacks 0
  ]
    set i i + 1
    if i = Number-of-Farmers [stop]
  ]
end


to define_farms ;total area that is available to a farmer for production
  set i 0

  ask farmers [
    let j 0
    set i i + 1
    let ll 0
    while [ll < farm-size][
      set j j + 1
      let potential_farm patch-set patches in-radius j with [farmer_owner = 0]
      if (count potential_farm ) > 0[
        ask potential_farm [
          if ll < farm-size [
            set farmer_owner i
            set ll ll + 1
          ]
        ]
      ]
    ]
  ]
  set i 0
  ask farmers [
    set i i + 1
    set farm patch-set patches with [farmer_owner = i]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  define_pooc
  define_EU
  define_annual_productive_land
  fencing
  attacks
  calculate_income
  fence_decay
  landscape_visualization
  count-years
  subjective_risk
  clean_up
  tick
end




to define_pooc
  set A sum [Domain] of patches
  ask patches [
    set p_occ ( N / A ) * (sum [Quality * Domain] of neighbors + (Quality * Domain)) / 9
  ]
end




to define_EU
  ask farmers [
    ask farm [

      set EU_NF [subjective-risk] of myself * (((price * Yield_Q * (1 - damage) - Cost_Y) / labor_AGRO)) + (1 - [subjective-risk] of myself) * (((price * Yield_Q - Cost_Y) / labor_AGRO))                     ; expected utility without a fence
      set EU_WF ((price * Yield_Q - Cost_Y) / (labor_AGRO + labor_fencing))                                                                                                          ; expected utility with a fence
      set EU_WF_maint [subjective-risk] of myself * ((price * Yield_Q * (1 - damage) - Cost_Y) / (labor_AGRO + (1 - Domain) * labor_fencing)) + (1 - [subjective-risk] of myself) * ((price * Yield_Q - Cost_Y) / (labor_AGRO + (1 - Domain) * labor_fencing))   ; expected utility with a fence that needs to be maintained

      if Domain = 1 [
        ifelse EU_NF > EU_WF [
          set EU EU_NF
          set decision_fencing "NF"
          set labor_needed labor_AGRO
        ]
        [
          set EU EU_WF
          set decision_fencing "F"
          set labor_needed labor_AGRO + labor_fencing
        ]
      ]

      if Domain != 1[
        ifelse EU_NF > EU_WF_maint [
          set EU EU_NF
          set decision_fencing "NF"
          set labor_needed labor_AGRO
        ]
        [
          set EU EU_WF_maint
          set decision_fencing "MF"
          set labor_needed labor_AGRO + (1 - Domain) * labor_fencing
        ]
      ]
    ]
  ]
end


to define_annual_productive_land          ;;farmed_patches defines the number of sites designated for agriculture in a given year

  ask farmers[
    set farmed_patches patch-set farm
    while [sum [labor_needed] of farmed_patches > Tot_Labor] [
      set farmed_patches max-n-of (count farmed_patches - 1) farmed_patches [EU]
    ]
    ask farmed_patches [
      set Landtype "A"
    ]
  ]
end


to fencing
  ;change the domain of all the cells with attacks in the farmer patches
  ;set the cost of fencing the site
  ;set the time lost here

  ask farmers [
    ask farmed_patches with [decision_fencing = "F" or decision_fencing = "FM"][
      set Domain 0
    ]
  ]
end

to AA ;(double A)
  ;here we need to define the best function ..... u know what I mean
  ;And if you don't know... now you know ...professors [last prase should be pronounced with a gansta accent]!!!
end




to calculate_income
  ask farmers [
    let agro-yield sum [Yield_Q * (1 - damage)] of farmed_patches with [N_attacks_here > 0] + sum [Yield_Q] of farmed_patches with [N_attacks_here = 0]
    set Income price * agro-yield - cost_Y * count farmed_patches
  ]
end

to attacks
  ask farmers [
    ask farm [set N_attacks_here 0]  ;;erase fast events
    ask farmed_patches [                   ;;in patches of the farm that have beeen used for production an attach can happend
      set N_attacks_here ifelse-value (p_occ > random-float 1) [1] [0]
    ]
    set attacks_list replace-item counter attacks_list (sum [N_attacks_here] of farm)
    set count_total_attacks (sum [N_attacks_here] of farm)

  ]

end
to count-years
  set counter counter + 1
  if counter > 4 [set counter 0]
end
to clean_up

    ask farmers [
      ask farm [
        set Landtype "F"
        set labor_needed 0
      ]
    ]
  end


to fence_decay   ;; face that are not maitained
ask patches with [domain < 1] [
  set domain domain + 0.1
  if domain > 1 [set domain 1]
]
end

;##################################################################################################################################################
;##################################################################################################################################################

to subjective_risk
  ask farmers [
    let tt map [delta ^ (5 - ?)][1 2 3 4 5]

    if-else social-influence = TRUE [
      let attacks_neigh ifelse-value (any? my-links) [map [ round mean [item ? attacks_list] of farmers with [link-neighbor? myself = TRUE]][0 1 2 3 4]][(list 0 0 0 0 0)]
      set s sum (map * tt attacks_neigh)
    ][
      set s sum (map * tt attacks_list)
    ]
    let w_t []
    (foreach attacks_list tt
      [
        ifelse (?1 > 0) [set w_t lput (?1 * ?2) w_t][set w_t lput ?2 w_t]
      ])
    set subjective-risk (s + mean [p_occ] of farm) / (sum w_t)

  ]
end
;##################################################################################################################################################
;##################################################################################################################################################
to setup-spatially-clustered-network
  let num-links (average-node-degree * Number-of-Farmers) / 2
  while [count links < num-links ]
  [
    ask one-of farmers
    [
      let choice (min-one-of (other farmers with [not link-neighbor? myself])[distance myself])
      if choice != nobody [ create-link-with choice ]
    ]
  ]
end
;##################################################################################################################################################
;##################################################################################################################################################
to landscape_visualization
  if color_Landscape = "Quality Agro" [
    let max_YQ max [Yield_Q] of patches
    ask patches [
      set pcolor scale-color green Yield_Q 0 max_YQ
    ]
  ]
  if color_Landscape = "Attacks" [
    ask patches with [landtype = "F"][
      set pcolor 55
      if N_attacks_here = 1 [set pcolor 15]
    ]
    ask patches with   [landtype = "A"][
      set pcolor 5
      if N_attacks_here = 1 [set pcolor 15]
    ]
  ]
  if color_Landscape = "Fenced patches" [
    ask patches with [Domain < 1][
      set pcolor scale-color blue Domain 1 0
    ]
    ask patches with [Domain = 1 and landtype = "F"][
      set pcolor 55
    ]
    ask patches with [Domain = 1 and landtype = "A"][
      set pcolor 5
    ]
  ]
  if color_Landscape = "objective probability of occupancy" and ticks > 1[
    let max_pooc max [p_occ] of patches
    ask patches with [landtype = "A"][
      set pcolor scale-color red p_occ 0 max_pooc
    ]
    ask patches with [landtype = "F"][
      set pcolor 55
    ]
  ]
  if color_Landscape = "farms" [
    ask patches with [farmer_owner > 0][
      set pcolor farmer_owner
    ]
    ask patches with [farmer_owner = 0][
      set pcolor 55
    ]
  ]

end
;##################################################################################################################################################
;##################################################################################################################################################
;##################################################################################################################################################
@#$#@#$#@
GRAPHICS-WINDOW
273
39
701
488
-1
-1
4.14
1
10
1
1
1
0
0
0
1
0
100
0
100
0
0
1
ticks
30.0

BUTTON
24
206
90
239
NIL
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
23
240
86
273
NIL
Go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
299
192
332
N
N
10
1000
748
1
1
Animals
HORIZONTAL

SLIDER
21
333
193
366
price
price
0
10
2.4
0.1
1
NIL
HORIZONTAL

SLIDER
12
56
185
89
Number-of-Farmers
Number-of-Farmers
1
500
178
1
1
farmers
HORIZONTAL

CHOOSER
377
489
615
534
Color_Landscape
Color_Landscape
"Quality Agro" "Attacks" "Fenced patches" "objective probability of occupancy" "farms"
2

SLIDER
13
20
185
53
distance-btw-households
distance-btw-households
3
100
12
1
1
NIL
HORIZONTAL

BUTTON
85
240
148
273
NIL
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
19
403
191
436
labor_fencing
labor_fencing
0
2
0.3
0.1
1
NIL
HORIZONTAL

PLOT
711
196
958
346
Income
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
"default" 1.0 0 -16777216 true "" "if ticks > 1 [\nplot mean [income] of farmers\n]"

SLIDER
19
368
191
401
damage
damage
0
1
0.2
0.01
1
NIL
HORIZONTAL

SLIDER
11
91
183
124
farm-size
farm-size
0
40
32
1
1
NIL
HORIZONTAL

PLOT
712
40
959
190
total # of attacks
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
"default" 1.0 0 -16777216 true "" "plot sum [count_total_attacks] of farmers"

PLOT
711
350
958
500
average p_occ
NIL
NIL
0.0
10.0
0.0
0.0010
true
true
"" ""
PENS
"pen-1" 1.0 0 -7500403 true "" "if ticks > 1 [plot N / A]"

SLIDER
10
125
182
158
average-node-degree
average-node-degree
0
10
7
1
1
NIL
HORIZONTAL

TEXTBOX
270
544
1022
840
\"Quality Agro\": Tones of green to represent the quality the patch for agriculture. Ligher tones for more productive patches\n\n\"Attacks\": To show the attacks that occur in the patches with agriculture production\n\n\"Fenced patches\": To  show the state of a fence using blue tones. Darker for newer fence (that is D=~0). Lighter tones represent older or not fence at all (D=1).\n\n\"Objective probability of occupancy\": To show the true probability of an attack. darker tones for higher probability.\n\n\"Farms\": Each color represents the sites that belong to a farmer. \n\nGreen patches represent the area not occupied by farmers (Forest land)
14
0.0
1

SWITCH
140
474
280
507
social-influence
social-influence
0
1
-1000

PLOT
978
185
1178
335
plot 1
NIL
NIL
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count patches with [domain < 1]"

@#$#@#$#@
## WHAT IS IT?
This model simulates a group for farmers and their farmland where they produce crops. This production is reduced when they suffer attacks from a wildlife population that inhabit the landscape. Farmers can reduce the risk of being expose to these attacks by acting in the landscape, such that the suitability of patches for wildlife is reduced. We called this "fencing". Farmers must decide whether or not to invest time in creating and maintaining a fences troghout the farm, by calculating an expected utility they would obtain with and without fencing. The expectation of economic return depends on the labor invested and on their subjective perception that an attack may occur in their property. This subjective probability depends on past attacks suffered by the farmers, but also on the social network in which the farmers are embedded. By comparing the expected utility of this different actions in each patch of their farm land they decide what patches to farm and what actions to take each year.
## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>sum [domain] of patches</metric>
    <metric>mean [income] of farmers</metric>
    <metric>sum [count_total_attacks] of farmers</metric>
    <metric>N / A</metric>
    <enumeratedValueSet variable="farm-size">
      <value value="32"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="10"/>
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="2.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-influence">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="damage" first="0.1" step="0.01" last="0.4"/>
    <enumeratedValueSet variable="labor_fencing">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="700"/>
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
