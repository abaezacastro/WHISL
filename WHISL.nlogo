extensions [csv rnd]
Globals [
  A                        ; Area for wildlife, weighted by quality and availability
  i                        ; counter
  cost_Y                   ; Cost of production (the same for all sites)
  new_farm                   ; auxiliar variable to define the farm of the farmers (used in setup the houses)
  max_labor                ; maximum labor available
  ;subjective risk
  alpha                    ;Dynamic Subjective Risk Beliefs parameter
  beta                     ;Dynamic Subjective Risk Beliefs parameter                    ;Dynamic Subjective Risk Beliefs parameter
  memory                       ;Dynamic Subjective Risk Beliefs parameter              store the encounters from the past


;;Auxiliar
  labor_fencing
  fdf     ;fdf: first degree friends auxiliar variable farmers use to evaluate the perception of risk from others
  sdn     ;sdf: second degree friends auxiliar variable farmers use to evaluate the perception of risk from others
]

breed [farmers farmer]
breed [wildlife wild]
wildlife-own[]
farmers-own [
  Income                   ; Income
  Income_past              ;income the timestep before
  Income_target         ;income target
  income_list
  income_list_full
  tot_income
  N_attacks_to_farmer      ; number of attacks a farmer received in a year
  farm                     ; set of patches that belong to a farmer and define the "farm"
  farmed_patches           ; set of patches designated to cultivation in a year
  Tot_Labor                ; total time available to farming
  total_fence
  total_attacks
  labor_available          ; labor available for farming each timestep acording to aspirational target income
  encounters_memory             ;list to save past attacks for adjusting subjective risk
  attacks_list_full        ;time series of every attack 1 if attack happened; 0 otherwise
  fence_list_total
  count_attacks      ;;total number of attacks in a year
  subjective-Risk
  my_firstD_neigh
  my_secondD_neigh
  p_occ_farm   ;objective probability inside farm
  suitability_farm_initial ;change of encounter
]

patches-own [
  Quality                  ; wildlife habitat quality
  availability             ; boolean variable to represent the availability of a site for wildlife. If availability=1 if the site is availalble; if availability < 1 the site is less usitable if D = 0 a fence is there
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

to SETUP
  clear-all
  reset-ticks


 ; let rv (random 100000)
 ; random-seed 47622
  quality_landscape        ;define quality of land
  set cost_Y operational_costs             ;need to be parametrized
  set max_labor farm-size * 2
  ask patches [
    set availability 1
    set Landtype "F"
    set decision_fencing "NF"
    set farmer_owner 0
    set labor_AGRO 2
  ]
  house_location
  define_farms

  if topology = "spatially-clustered"[
    setup-spatially-clustered-network
  ]
  if  topology = "random"[
    setup_random_network
  ]
  landscape_visualization
 ; export_initial_conditions

;    random-seed rv
  wildlife_setting
end

to quality_landscape        ;here we define the quality of the patch for agriculture
 if landscape_scenario = "mix Landscape"[
      ask patches [
        set Yield_Q 1 + random-normal ave_yield_ppatch  sqrt ave_yield_ppatch  ;Agro quality
        set Quality  random-float 1;(max-pxcor - pxcor) / max-pxcor   ;quality for wildlife
      ]
 ]

if landscape_scenario = "protected-area-gradient"[
            ask patches [
        set Yield_Q ave_yield_ppatch * (max-pxcor - pxcor) / max-pxcor
        set Quality  pxcor / max-pxcor
      ]
]



end
;###################################################################################################
to wildlife_setting
  create-wildlife N[
    set xcor random-xcor
    set ycor random-ycor
    set shape "wolf"
    set size 2
    set color black
     move-to rnd:weighted-one-of patches [quality]
  ]
end

to move-wildlife  ;;change movement of wildlife 1) radius
  ask wildlife [
    move-to rnd:weighted-one-of patches in-radius movement_radius [availability * quality]
  ]
end
;###################################################################################################
to house_location ;; houses allocated in areas with higher agro quality

  create-farmers round (Number-of-Farmers * 0.1) [
    ; here we can assign the location based on land productivity and density
    move-to one-of max-n-of 10 (patches with [not any? farmers-here]) [Yield_Q]
    set shape "house"
    set size 5
    set Tot_Labor farm-size * 2;; set the available labor
    set Income 1
    set encounters_memory [0 0 0 0 0]
    set attacks_list_full []
    set income_list (list 0 0 0 0 0)
    set income_list_full []
    set fence_list_total []
    set count_attacks 0
    set total_attacks 0
    set labor_available Tot_Labor
  ]

  set i count farmers
  loop [
    ask one-of farmers [
    set new_farm one-of patches in-radius distance-btw-households with [not any? farmers-here]
    ]
  create-farmers 1 [
    ; here we assign the location based on land productivity and density

    move-to new_farm

    set shape "house"
    set size 5
    set Tot_Labor farm-size * 2;; set the available labor
    set Income 1
    set encounters_memory [0 0 0 0 0]
    set attacks_list_full []
    set income_list (list 0 0 0 0 0)
    set income_list_full []
    set fence_list_total []
    set count_attacks 0
    set total_attacks 0
    set labor_available Tot_Labor
  ]
    set i i + 1
    if i = Number-of-Farmers [stop]
  ]


end
;###################################################################################################
;###################################################################################################
to define_farms ;to define the total area that is available to a farmer for production, and the income_target, which is based on land productivity and aspirational level.
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
    set Income_target (sum [Yield_Q * price - cost_Y] of patches with [farmer_owner = i]) * aspirations

  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go

  define_pooc
  define_availableLabor ;1 every 12 timesteps
  define_EU  ;1 every 12 timesteps
  define_annual_productive_land ;1 every 12 timesteps
  fencing ;1 every 12 timesteps
  repeat 12 [
    move-wildlife ;1 every timestep
    attacks        ;1 every timestep
    fence_decay   ;1 every timestep
  ]
  calculate_income ;1 every 12 timesteps
  subjective_riskB ;1 every timestep
  landscape_visualization
  if ticks = 200[write-timeseries-data]
  ;ask farmers [set size s_f * Income / 10]
  save_outputs_and_cleanup
  tick
end

;#######################################################################################################################################
to define_pooc  ;change to gamma distribution
  let Area sum [availability] of patches

  ask patches [
    set p_occ Quality * N / Area
  ]
ask farmers [
    set p_occ_farm mean [p_occ] of farm
  ]
end

;#######################################################################################################################################
to define_availableLabor
  ask farmers [
    if-else ticks = 1 [
      set income_past 0]
    [
    ifelse income_past  > Income_target [
      set Tot_Labor labor_available - ((abs (income_past - Income_target)) / wage)
      if Tot_Labor < 1 [set Tot_Labor 1]
    ][
      set Tot_Labor  labor_available + ((abs (Income_target - income_past)) / wage)
      if Tot_Labor > max_labor [set Tot_labor max_labor]
    ]

    set labor_available Tot_Labor
    ]
 ; print (list  Tot_Labor labor_available ((income_past - Income_target) / wage))
  ]
end


;#######################################################################################################################################
to define_EU
  ask farmers [
    ask farm [
      set labor_fencing labor_ratio * labor_AGRO
      set EU_NF [subjective-risk] of myself * (((price * Yield_Q * (1 - damage) - Cost_Y) / labor_AGRO)) + (1 - [subjective-risk] of myself) * (((price * Yield_Q - Cost_Y) / labor_AGRO))                     ; expected utility without a fence
      set EU_WF ((price * Yield_Q - Cost_Y) / (labor_AGRO + labor_fencing))                                                                                                          ; expected utility with a fence
;      set EU_WF_maint [subjective-risk] of myself * ((price * Yield_Q * (1 - damage) - Cost_Y) / (labor_AGRO + availability * labor_fencing)) + (1 - [subjective-risk] of myself) * ((price * Yield_Q - Cost_Y) / (labor_AGRO + availability * labor_fencing))   ; expected utility with a fence that needs to be maintained
      ;      if availability = 1 [
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
 ;     ]


    ]
  ]
end

;#######################################################################################################################################
to define_annual_productive_land          ;;define_annual_productive_land defines the time designated to agricultural activities in a given year

  ask farmers[

    set farmed_patches patch-set farm
    while [sum [labor_needed] of farmed_patches > labor_available] [
      set farmed_patches max-n-of (count farmed_patches - 1) farmed_patches [EU]
    ]
    ask farmed_patches [
      set Landtype "A"
    ]
  ]
end

;#######################################################################################################################################
to fencing
  ;change the availability of all the cells with attacks in the farmer patches
  ;set the cost of fencing the site
  ;set the time lost here

  ask farmers [
    ask farmed_patches with [decision_fencing = "F"][
      set availability 0
    ]
    ask farmed_patches with [decision_fencing = "NF"][
      set availability availability
    ]
  ]
;fence decay at at rate proportional to the cycle of decision
;
end
;#######################################################################################################################################

to calculate_income
  ask farmers [
    set income_past mean Income_list
    let agro-yield sum [Yield_Q] of farmed_patches  -  count_attacks * ave_yield_ppatch * damage
    set Income price * agro-yield -  cost_Y * count farmed_patches
    let ilau (but-first income_list)
    set income_list lput floor Income ilau
    set income_list_full lput floor Income income_list_full
    if ticks > (100) [set tot_income tot_income + Income]
  ]
end
;#######################################################################################################################################
to attacks
  ask farmers [
    ask farmed_patches [                   ;;an attack can happen in patches inside the farm used for production
      set N_attacks_here count wildlife-here
    ]
    ;set encounters_memory replace-item counter encounters_memory (sum [N_attacks_here] of farm) ;
    set count_attacks (sum [N_attacks_here] of farm)
    set total_attacks total_attacks + count_attacks
  ]
end


to save_outputs_and_cleanup
    ask farmers [
    set total_fence total_fence + count farm with [availability < 1]
    set fence_list_total lput count farm with [availability < 1] fence_list_total
    set attacks_list_full lput count_attacks attacks_list_full
    let n_list but-first encounters_memory
    set encounters_memory lput count_attacks n_list
    set count_attacks 0
      ask farm [
        set Landtype "F"
        set labor_needed 0
        set N_attacks_here 0
      ]
    ]
end

to fence_decay  ;; face that are not maitained
  ask patches with [availability < 1][
    set availability availability + decay
    if availability > 1 [set availability 1]
  ]
end

;##################################################################################################################################################
;##################################################################################################################################################

to subjective_risk
  ask farmers [
    set beta (1 - p_occ_farm) / p_occ_farm;(1 - (mean [p_occ] of farm)) / (mean [p_occ] of farm)
    let dd map [ ?1 -> memory_decay ^ (5 - ?1) ][1 2 3 4 5]

    if-else social-influence = TRUE [
      ;let attacks_neigh ifelse-value (any? my-links) [map [ round mean [item ? encounters_memory] of farmers with [link-neighbor? myself = TRUE]][0 1 2 3 4]][(list 0 0 0 0 0)]

      set fdf map [ ?1 -> sum [item ?1 encounters_memory] of my_FIRSTD_neigh ][0 1 2 3 4]
      set sdn (map [ ?1 -> sum [item ?1 encounters_memory] of my_secondD_neigh ][0 1 2 3 4])

      let attacks_neigh (map [ [?1 ?2 ?3] -> 0.25 * ?1 + (0.15 * ?2) + 0.60 * ?3 ] fdf sdn encounters_memory)

      set memory sum (map * dd attacks_neigh)
        let w_t []
        (foreach attacks_neigh dd
          [[a_var b_var] ->
            ifelse (a_var > 0) [set w_t lput (a_var * b_var) w_t][set w_t lput 1 w_t]
        ])

        set subjective-risk (memory + alpha) / (sum w_t + alpha + beta)
    ]

    [ ;no social influence



        set memory sum (map * dd encounters_memory)
        let w_t []
        (foreach encounters_memory dd
          [ [a_var b_var]->
            ifelse (a_var > 0) [set w_t lput (a_var * b_var) w_t][set w_t lput 1 w_t]
        ])

        set subjective-risk (memory + alpha) / (sum w_t + alpha + beta)
      ]

  ]
end


to subjective_riskB
  ask farmers [
    let mean_p p_occ_farm

    set beta (alpha * (1 - mean_p)) / mean_p;(1 - (mean [p_occ] of farm)) / (mean [p_occ] of farm)
    let dd map [ ?1 -> memory_decay ^ (5 - ?1) ][1 2 3 4 5]



        set memory sum (map * dd encounters_memory)
        let w_t []
        (foreach encounters_memory dd
          [ [a_var b_var]->
            ifelse (a_var > 0) [set w_t lput (a_var * b_var) w_t][set w_t lput 1 w_t]
        ])

        set subjective-risk (memory + alpha) / (sum w_t + alpha + beta)
  ]
  if social-influence = TRUE [
    ask farmers [
      if-else empty? [subjective-risk] of my_FIRSTD_neigh[
        set fdf 0
      ]
      [
        set fdf max [subjective-risk] of my_FIRSTD_neigh
      ]
      if-else empty? [subjective-risk] of my_secondD_neigh[
        set sdn 0
      ]
      [
        set sdn max [subjective-risk] of my_secondD_neigh
      ]
      set subjective-risk w1 * subjective-risk + 0.5 * (1 - w1) * fdf + 0.5 * (1 - w1) * sdn
    ]
  ]



end

;##################################################################################################################################################
;##################################################################################################################################################
to setup-spatially-clustered-network                                       ;to create a network of farmers  ;distance !!!!!Cite Virus on a Network Netlogo library!!!
  let num-links (average-node-degree * Number-of-Farmers) / 2
  while [count links < num-links ]
  [
    ask one-of farmers
    [
      let choice (min-one-of (other farmers with [not link-neighbor? myself])[distance myself])
      if choice != nobody [ create-link-with choice [
          set thickness 3
          set color magenta] ]
    ]
  ]

  ask farmers [
    set my_firstD_neigh turtle-set [other-end] of my-links                           ;to define the set agentthe first order neighbors of farmers
    set my_secondD_neigh turtle-set [[other-end] of my-links] of my_firstD_neigh     ;to define the agentset the second order neighbors of farmers (friends of my friends)
    set my_secondD_neigh my_secondD_neigh with [who != [who] of myself]              ;remove the calling farmers from the second degree links
  ]
end
;##################################################################################################################################################
to setup_random_network
  let num-links (average-node-degree * Number-of-Farmers) / 2
  while [count links < num-links ]
  [
    ask one-of farmers
    [
      let choice one-of (other farmers with [not link-neighbor? myself])
      if choice != nobody [ create-link-with choice [
          set thickness 0.5
          set color magenta] ]
    ]
  ]

  ask farmers [
    set my_firstD_neigh turtle-set [other-end] of my-links                           ;to define the set agentthe first order neighbors of farmers
    set my_secondD_neigh turtle-set [[other-end] of my-links] of my_firstD_neigh     ;to define the agentset the second order neighbors of farmers (friends of my friends)
    set my_secondD_neigh my_secondD_neigh with [who != [who] of myself]              ;remove the calling farmers from the second degree links
  ]
end
;##################################################################################################################################################
to landscape_visualization
  if color_Landscape = "Quality Agro" [
    let max_YQ max [Yield_Q] of patches
    ask patches [
      set pcolor scale-color green Yield_Q 0 max_YQ
    ]
  ]
  if color_Landscape ="Quality for wildlife"[
    let max_Q max [quality * availability] of patches
    ask patches [
      set pcolor scale-color green (quality * availability) 0 max_Q
    ]
  ]
  if color_Landscape = "Attacks" [
    ask patches with [farmer_owner > 0][
      if-else (N_attacks_here > 0) [set pcolor 15][set pcolor 0]
    ]
  ]
  if color_Landscape = "Fenced patches" [
    ask patches with [availability < 1][
      set pcolor scale-color blue availability 1 0
    ]
    ask patches with [availability = 1 and landtype = "F"][
      set pcolor 55
    ]
    ask patches with [availability = 1 and landtype = "A"][
      set pcolor yellow
    ]
  ]
  if color_Landscape = "objective probability of occupancy" and ticks > 1[
    ask farmers[
      ask farm[
      set pcolor farmer_owner + [p_occ_farm] of myself  * farmer_owner
      ]
    ]
  ]
  if color_Landscape = "farms" [
    ask patches with [farmer_owner > 0][
      set pcolor farmer_owner * availability
    ]
    ask patches with [farmer_owner = 0][
      set pcolor 55
    ]
  ]

end


;##################################################################################################################################################
;##################################################################################################################################################
to export-map
; let PATH "c:/Users/abaezaca/Dropbox (ASU)/Documents/Carnivore_coexistance/risk-perception-wildlife-attack/simulation_results/"
 file-open (word "Fixed_" (word landscape_scenario "-" (word N_run "-" (word average-node-degree "-" (word damage "-" (word w1 "-" (word movement_radius (word "LS.txt"))))))))

 ;   if file-exists? fn
  ;  [ file-delete fn]
  ;  file-open fn


    file-write distance-btw-households
    file-write Number-of-Farmers
    file-write farm-size
    file-write average-node-degree
    file-write N
    file-write damage
    file-write labor_fencing
    file-write w1

    foreach sort-on [who] farmers[ ?1 ->
      ask ?1
      [
       file-write who                                    ;;write the ID of each ageb using a numeric value (update acording to Marco's Identification)
        file-write xcor                   ;;write the value of the atribute
        file-write ycor
        file-write total_attacks
        file-write total_fence
        file-write tot_income
        file-write sum [total_attacks] of my_FIRSTD_neigh
        file-write sum [total_attacks] of my_secondD_neigh
        file-write count my_FIRSTD_neigh + count my_secondD_neigh
       ]
    ]
    file-close                                        ;close the File
end
;##################################################################################################################################################
;##################################################################################################################################################
to write-timeseries-data   ;;;add risk perception to the outputs
    let ppcsv []
    let ICcsv []
    let Dcsv []
    foreach sort-on [who] farmers[ ?1 ->
      ask ?1[
      set attacks_list_full fput pycor attacks_list_full
      set attacks_list_full fput pxcor attacks_list_full
      set income_list_full  fput pycor income_list_full
      set income_list_full  fput pxcor income_list_full
      set fence_list_total fput pycor fence_list_total
      set fence_list_total fput pxcor fence_list_total
      set ppcsv lput attacks_list_full ppcsv
      set ICcsv lput income_list_full ICcsv
      set Dcsv lput fence_list_total Dcsv
    ]
    ]

    csv:to-file (word "2Fixed_LS_TS_attacks" "-" (word landscape_scenario "-" (word N_run "-"  (word average-node-degree "-" (word damage "-" (word movement_radius "-" (word w1 ".csv"))))))) ppcsv
    csv:to-file (word "2Fixed_LS_TS_income"  "-" (word landscape_scenario "-" (word N_run "-" (word average-node-degree "-" (word damage "-" (word movement_radius "-" (word w1 ".csv"))))))) ICcsv
    csv:to-file (word "2Fixed_LS_TS_availability"  "-" (word landscape_scenario "-" (word N_run "-" (word average-node-degree "-" (word damage "-" (word movement_radius "-"(word w1 ".csv"))))))) Dcsv
end

;##################################################################################################################################################
;##################################################################################################################################################
to re-wire
    ask links [ die ]
  if topology = "spatially-clustered"[
    setup-spatially-clustered-network
  ]
  if  topology = "random"[
    setup_random_network
  ]
end
;##################################################################################################################################################
;##################################################################################################################################################
;##################################################################################################################################################
to export_initial_conditions
; let PATH "c:/Users/abaezaca/Dropbox (ASU)/Documents/Carnivore_coexistance/risk-perception-wildlife-attack/simulation_results/"
 file-open (word "2Initital_Availability_Fixed_" (word landscape_scenario "-" (word N_run "-" (word average-node-degree "-" (word damage "-" (word w1 "-" (word movement_radius "-" (word "LS.txt"))))))))

  ask farmers [
  set suitability_farm_initial  sum [Quality] of farm
  ]

 ;   if file-exists? fn
  ;  [ file-delete fn]
  ;  file-open fn


    file-write distance-btw-households
    file-write Number-of-Farmers
    file-write farm-size
    file-write average-node-degree
    file-write N
    file-write damage
    file-write labor_fencing
    file-write w1

    foreach sort-on [who] farmers[ ?1 ->
      ask ?1
      [
       file-write who                                    ;;write the ID of each ageb using a numeric value (update acording to Marco's Identification)
        file-write xcor                   ;;write the value of the atribute
        file-write ycor
         file-write suitability_farm_initial
        file-write sum [total_attacks] of my_FIRSTD_neigh
        file-write sum [total_attacks] of my_secondD_neigh
        file-write count my_FIRSTD_neigh + count my_secondD_neigh
       ]
    ]
    file-close                                        ;close the File
end
;##################################################################################################################################################
@#$#@#$#@
GRAPHICS-WINDOW
536
10
927
402
-1
-1
1.91
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
200
0
200
0
0
1
ticks
30.0

BUTTON
384
221
448
255
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
385
256
448
289
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
9
160
181
193
N
N
10
100
50.0
1
1
Animals
HORIZONTAL

SLIDER
9
194
181
227
price
price
0.1
4
0.7
0.01
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
100
80.0
1
1
farmers
HORIZONTAL

CHOOSER
362
19
535
64
Color_Landscape
Color_Landscape
"Quality Agro" "Quality for wildlife" "Attacks" "Fenced patches" "objective probability of occupancy" "farms" "EU"
1

SLIDER
13
20
185
53
distance-btw-households
distance-btw-households
3
100
40.0
1
1
NIL
HORIZONTAL

BUTTON
450
255
516
288
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
10
262
182
295
labor_ratio
labor_ratio
0
2
0.2
0.1
1
NIL
HORIZONTAL

PLOT
263
340
504
487
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
8
229
180
262
damage
damage
0
1
0.8
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
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
10
125
182
158
average-node-degree
average-node-degree
0
10
4.0
1
1
NIL
HORIZONTAL

TEXTBOX
939
25
1208
355
                    Landscape visualization\n\"Quality Agro\": Tones of green to represent the quality the patch for agriculture. Ligher tones for more productive patches\n\n\"Encounters\": To show the when a human-wildlife interaction occured in the patches with agriculture production.\n\n\"Fenced patches\": To  show the state of the exclussion using blue tones. Darker for newer (that is D!=0). Lighter tones represent older or not fence at all (D=1).\n\n\"Objective probability of occupancy\": To show the true probability of an attack. darker tones for higher probability.\n\n\"Farms\": Each color represents the sites that belong to a farmer. \n\nGreen patches represent the area not occupied by farmers (Forest land)
12
0.0
1

SWITCH
388
180
515
213
social-influence
social-influence
0
1
-1000

PLOT
11
338
259
488
Cells with protection againt wildlife
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
"default" 1.0 0 -16777216 true "" "plot sum [1 - availability] of patches with [farmer_owner > 0]"

SLIDER
10
299
182
332
wage
wage
1
20
20.0
0.1
1
NIL
HORIZONTAL

SLIDER
186
267
358
300
N_run
N_run
1
10
9.0
1
1
NIL
HORIZONTAL

CHOOSER
361
114
535
159
landscape_scenario
landscape_scenario
"mix Landscape" "protected-area-gradient"
1

CHOOSER
362
66
534
111
topology
topology
"random" "spatially-clustered"
1

BUTTON
450
221
516
254
NIL
re-wire
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
187
127
359
160
ave_yield_ppatch
ave_yield_ppatch
0
100
28.0
1
1
NIL
HORIZONTAL

SLIDER
187
57
361
90
operational_costs
operational_costs
0
100
4.0
0.001
1
NIL
HORIZONTAL

SLIDER
187
233
359
266
memory_decay
memory_decay
0
2
0.7
0.1
1
NIL
HORIZONTAL

MONITOR
575
419
824
464
Average subjective risk of the population
precision mean [subjective-risk] of farmers 2
3
1
11

SLIDER
187
92
359
125
aspirations
aspirations
0
1
0.8
0.1
1
NIL
HORIZONTAL

SLIDER
187
19
359
52
w1
w1
0
1
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
187
161
359
194
movement_radius
movement_radius
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
187
195
359
228
decay
decay
0.001
0.1
0.01
0.0001
1
NIL
HORIZONTAL

@#$#@#$#@
# Wilidlife-Human Interactions Shared Landscapes
# THE WHISL MODEL


## INTRODUCTION

This model simulates a group of farmers that have encounters with individuals of a wildlife population. The model also simulates the movement of the individual of the wildlife population. Each farmer owns a set of patches that represent they farmland. A farm is a group of patches or cells. Each farmer must decide what cells inside their farm they will use to produce agriculture. The farmer must also decide if it will protect the cells from the individuals of the wildlife population entering their farm. We call this action "to fence". Each time that a cell is fenced, the changes of the individual to move to that cell is reduced. Each encounter reduces the productivity of the agriculture in a pach impacted. Farmers therefore can reduce the risk of encounters by excluding them by fencing. 

Each farmer calculates an expected economic return (or income) per cell by producing crops and expluding wildlife. This decisions are made considering the perception of risk of encounters. The perception of risk is subjective because it depends on past encounters and on the perception of risk from other farmers in the community. The community of farmers passes information about this risk throught in a social network. The effect of the opinions of others is represented by parameters (1-w1). The higher the effect of other agents the more they care about others' opinions. The model evaluates how social interactions affect the number of encounters and the suitability of the landscape for wildlife.

The model was developed by Andres Baeza, and to cite the paper and read details about the implementation and how it has been used see Carter, Baeza and Magliocca (in review 2018).


## HOW IT WORKS

Each tick represents a year. In each yach year farmers made decisions to maximize the return of income given the aspiration of the farmers and previous income. First, they decide how much land they will allocate to agriculture. This is done by comparing the income of the last interation againt a target income, which is calculated as a moving average of the income for the last 5 years. Then, the farmer decides to fence or not those patches desginaded for production. The model assumes that each encounter is percived as a economic burden to the economic output, and represented by the paramater "damage".


They evaluate the expected income they will receive considering the risk of encounters. For details on how the risk is implemented see [Carter _etal_2019_Inreview.docx]

After the decision by the farmers about protecting their farm is taken, the model simulates 10 cycles of wildlife movement. In each of these cycles, the individuals of the wildlife population will move to a cell randomly choosen from a set of cells in a radius of size r. The chances of moving to a cell depends on the suitability of the cell, which in turn depends on the availability of the cell to be occupied and the quality of wildlife, assigend to the cell at the begening of the simulation. The availability of the cell is directly proportional to the condition of the fence, which decays at a fixed rate (decay).


## HOW TO USE IT

Before running the model, the observer must press the setup buttom. 
The user before setup must choose:

### The type of landscape 
This will define the spatial structure of the quality of each patch to support agriculture or the wildlife population.

#### Mixed-landscape
In this case the quality of the cells for agriculturee and to support wildlife are randomly distributed in the landscape.

#### Gradient
This landscape represents a linear change in quality. In this setting as the quality of the cell for agriculture decreases from the left to right of the screen, the quality of the cell to support wildlife increases. This means that the gradient landscape is assimetric. This landscape main to represent a landscape that resembles the edge of a protected area.

### The topology of the social network
This will define how the interactions between the farmers will be setup. 

##### Spatially clustered
In this setup, farmers are more likely to be connected to ofther farmers closte in distance.

##### Random
This setting simualte a random network. Each farmer can be connected any other farmer in the landscape.


### Sliders
There are several parameters the observer can modify:
 1.  The average distance between farmers 
2.  The Number of farmers
3.  The size of the farms
4.  The average number of social connections
5.  The size of the wildlife population
6  The price of the crop
7.  The damage of an encounter
8.  The cost of fencing relative to the production cost
9.  The average productivity of a cell
10. The off-farm wage per unit of labor 
11. The importance farmers give to their own risk (parameter w1.
12. The operational cost per cell of agriculture
13. The aspiration level of the farmers (proportion of maximum posible Income, which  depend on the size of the farm and the quality of the cells inside the farm)
14. The average potential agriculture yield of a cell if dedicaded to production. 
15.  The radius of mobility of an individual of the wildlife population
16. The rate of decay of a fence over time

## THINGS TO NOTICE

In the visualization mode "fences", the user will notice the formation of areas protected and its decay over time. Change the level of damage to see how the formation of fences changes as the damage of each encounter is modify. 
Using the slider "movement_radius" to modify the maximum distance the individuals of the wildlife population are able to move in a single time-step. 

## THINGS TO TRY

Try to modify parameters damage and parameter movement-radius, sistematically to simualte how the damage and animal mobility interact to influence the oucome of the model. The user can define four different populations of the wildlife combining low or high damage, with small or large distance for movement.

## EXTENDING THE MODEL

### Animal movement
The model simulates the movement of the individuals of the wildelife population. This is curretnly implemented as a random process using a very simple algorithm that take into account the quality fo the cells to support wildlife and the availability of the cell based on the decision of the farmers to fence the cells. In reality, animal movement is the outcome of the decision of the animal to move to one area or another and is influenced by many other factors. The user can modified this alrogirmth to include more complex decision-making processes that can take into account for example:

The level of energy, 
the quality of the cells for agriculture, 
the number of farmers, or 
the expiriance gained from previous encounters.

### Population dynamics and other control methods
The model includes only a control method that explude animals from the farm. The model however does not include hunting or explussion, neither population dynamics in terms of borthds and deads of the wildlife population.


## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

### Virus on a Network 
Stonedahl, F. and Wilensky, U. (2008). NetLogo Virus on a Network model. 

http://ccl.northwestern.edu/netlogo/models/VirusonaNetwork. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.)

## CREDITS AND REFERENCES

Copyright 2018 Andres Baeza.

### Reference to the code

https://github.com/abaezacastro/risk-perception-wildlife-attack/blob/master/Risk_Attack_model_V61.nlogo

### Reference to the paper

Carter, N., Baeza, A., Maglioca, N., 2019. Social contagion of risk perception in human-wildlife interactions. In_Preparation.

### License

<a rel="license" href="http://creativecommons.org/licenses/by-nc/3.0/us/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc/3.0/us/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc/3.0/us/">Creative Commons Attribution-NonCommercial 3.0 United States License</a>.
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
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="vary_demage_v61_LS_PALandscapelarge_mobility" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - availability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="farm-size">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement_radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-influence">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="damage" first="0.1" step="0.1" last="1"/>
    <enumeratedValueSet variable="labor_fencing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;protected-area-gradient&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="distance_btw_houses_V61" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - availability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farm-size">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wage">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-influence">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;mix Landscape&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="prices_V61" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - availability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farm-size">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.3"/>
      <value value="0.5"/>
      <value value="0.7"/>
      <value value="0.9"/>
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wage">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-influence">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;mix Landscape&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="links_V61" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - availability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farm-size">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wage">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;mix Landscape&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Correlogram_v61" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-timeseries-data</final>
    <timeLimit steps="200"/>
    <enumeratedValueSet variable="farm-size">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="labor_fencing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N_run">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
      <value value="9"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement_radius">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;mix Landscape&quot;"/>
      <value value="&quot;protected-area-gradient&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="spatialPattern_v61" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-map</final>
    <timeLimit steps="200"/>
    <enumeratedValueSet variable="farm-size">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="labor_fencing">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N_run">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement_radius">
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;mix Landscape&quot;"/>
      <value value="&quot;protected-area-gradient&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Farm_size_V2_PA" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - availability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="40"/>
    </enumeratedValueSet>
    <steppedValueSet variable="farm-size" first="10" step="10" last="100"/>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;protected-area-gradient&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ave_yield_ppatch">
      <value value="28"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-influence">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aspirations">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="operational_costs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement_radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="topology">
      <value value="&quot;spatially-clustered&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="labor_ratio">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wage">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect_of_distance" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-map</final>
    <timeLimit steps="200"/>
    <enumeratedValueSet variable="farm-size">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement_radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="labor_fencing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decay">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary_demage_v61_PAgradient" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - availability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="farm-size">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement_radius">
      <value value="1"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-influence">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="damage" first="0.1" step="0.1" last="1"/>
    <enumeratedValueSet variable="labor_fencing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;protected-area-gradient&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="distance_btw_houses_V61_PAGradient" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - availability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farm-size">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wage">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-influence">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;protected-area-gradient&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="prices_V61_PAgradient" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - availability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farm-size">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.3"/>
      <value value="0.5"/>
      <value value="0.7"/>
      <value value="0.9"/>
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wage">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-influence">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;protected-area-gradient&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="links_V61_PAgradient" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - availability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="farm-size">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wage">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;protected-area-gradient&quot;"/>
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
