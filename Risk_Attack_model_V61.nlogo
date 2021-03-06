extensions [csv r rnd]
Globals [
  A                        ; Area for wildlife, weighted by quality and availability
  table_landQ              ; table cost-quality
  i                        ; counter
  cost_Y                   ; Cost of production (the same for all sites)
  new_ff                   ; auxiliar variable to define new farmers (used in setup the houses)
  cost_f                   ; cost of fencing a site [$]
  m                        ; time of fencing a site [time]
  max_labor
  ;subjective risk
  alpha                    ;Dynamic Subjective Risk Beliefs parameter
  beta                     ;Dynamic Subjective Risk Beliefs parameter                    ;Dynamic Subjective Risk Beliefs parameter
  s
;;reporters
  tot_cost_production
  tot_damage


;;Auxiliar
  counter
  labor_fencing
  fdf
  sdn
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
]

patches-own [
  Quality                  ; wildlife habitat quality
  availability                   ; boolean variable to represent the availability of a site for wildlife. If availability=1 if the site is availalble; if availability < 1 the site is less usitable if D = 0 a fence is there
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
  let rv (random 100000)
  random-seed 47622

  quality_landscape        ;define quality of land
  set cost_Y operational_costs             ;need to be parametrized
  set counter 0
  set max_labor farm-size * 2
  ask patches [
    set availability 1
    set Landtype "F"
    set decision_fencing "NF"
    set farmer_owner 0
    set labor_AGRO 2
  ]
  house_location
  random-seed rv
  define_farms
  wildlife_setting
  if topology = "spatially-clustered"[
    setup-spatially-clustered-network
  ]
  if  topology = "random"[
    setup_random_network
  ]
  landscape_visualization
end

to quality_landscape        ;here we define the quality of the patch for agriculture
 if landscape_scenario = "mix Landscape"[
      ask patches [
        set Yield_Q 1 + random-normal ave_yield_ppatch  sqrt ave_yield_ppatch
        set Quality  random-float 1;(max-pxcor - pxcor) / max-pxcor
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
    set shape "dot"
    set color black]
end

to move-wildlife  ;;change movement of wildlife 1) radius
  ask wildlife [
;    ifelse any? patches in-radius movement_radius with [availability > 0] [
;    let patch_set_mov [availability * quality] of patches in-radius movement_radius
    ;print [availability * quality] of rnd:weighted-one-of patches in-radius movement_radius [availability * quality]
    ;let ID_p list [who] of patch_set_mov
    ;let vec_wights  [availability * quality] of patch_set_mov
    ;let sum_vec sum [availability * quality] of patch_set_mov
    ;let vector map [j -> j / sum_vec ] vec_wights ;
    ;print sum vector
    ;print patch_set_mov
    ;r:put "vec_w" vec_wights
    ;let choose_patch r:get "sample(x=1:length(vec_w),size=1, prob=vec_w)"
    ;print patch_set_mov with [who = item 0 ID_p]
    move-to rnd:weighted-one-of patches in-radius movement_radius [availability * quality]
;    ][
;        move-to one-of patches with [availability > 0] in-radius movement_radius
;      ]
  ]
end
;###################################################################################################
to house_location ;; houses allocated in areas with higher agro quality

  create-farmers round (Number-of-Farmers * 0.1) [
    ; here we can assign the location based on land productivity and density
    move-to one-of max-n-of 10 (patches with [not any? farmers-here]) [Yield_Q]
    set shape "house"
    set size 2
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
    set new_ff one-of patches in-radius distance-btw-households with [not any? farmers-here]
    ]
  create-farmers 1 [
    ; here we assign the location based on land productivity and density

    move-to new_ff

    set shape "house"
    set size 2
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

to define_pooc  ;change to gamma distribution
ask farmers [
  set p_occ_farm (N / sum [availability] of patches)
  ]
end


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


;####################################
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

;      if availability != 1[
;        ifelse EU_NF > EU_WF_maint [
;          set EU EU_NF
;          set decision_fencing "NF"
;          set labor_needed labor_AGRO
;        ]
;        [
;          set EU EU_WF_maint
;          set decision_fencing "MF"
;          set labor_needed labor_AGRO + availability * labor_fencing
;        ]
;      ]
;     print (list EU EU_WF EU_NF)
    ]
  ]
end


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

to AA ;(double A)
  ;here we need to define the best function ..... u know what I mean
  ;And if you don't know... now you know ...professors!!
end




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

to fence_decay   ;; face that are not maitained
  ask patches with [availability < 1][
    set availability availability + decay
    if availability > 1 [set availability 1]
  ]
end

;##################################################################################################################################################
;##################################################################################################################################################

to subjective_risk
  ask farmers [
    set beta 1 - p_occ_farm;(1 - (mean [p_occ] of farm)) / (mean [p_occ] of farm)
    let dd map [ ?1 -> delta ^ (5 - ?1) ][1 2 3 4 5]

    if-else social-influence = TRUE [
      ;let attacks_neigh ifelse-value (any? my-links) [map [ round mean [item ? encounters_memory] of farmers with [link-neighbor? myself = TRUE]][0 1 2 3 4]][(list 0 0 0 0 0)]

      set fdf map [ ?1 -> sum [item ?1 encounters_memory] of my_FIRSTD_neigh ][0 1 2 3 4]
      set sdn (map [ ?1 -> sum [item ?1 encounters_memory] of my_secondD_neigh ][0 1 2 3 4])

      let attacks_neigh (map [ [?1 ?2 ?3] -> 0.25 * ?1 + (0.15 * ?2) + 0.60 * ?3 ] fdf sdn encounters_memory)

      set s sum (map * dd attacks_neigh)
        let w_t []
        (foreach attacks_neigh dd
          [[a_var b_var] ->
            ifelse (a_var > 0) [set w_t lput (a_var * b_var) w_t][set w_t lput 1 w_t]
        ])

        set subjective-risk (s + alpha) / (sum w_t + alpha + beta)
    ]

    [ ;no social influence



        set s sum (map * dd encounters_memory)
        let w_t []
        (foreach encounters_memory dd
          [ [a_var b_var]->
            ifelse (a_var > 0) [set w_t lput (a_var * b_var) w_t][set w_t lput 1 w_t]
        ])

        set subjective-risk (s + alpha) / (sum w_t + alpha + beta)
      ]

  ]
end


to subjective_riskB
  ask farmers [
    let mean_p p_occ_farm

    set beta (alpha * (1 - mean_p)) / mean_p;(1 - (mean [p_occ] of farm)) / (mean [p_occ] of farm)
    let dd map [ ?1 -> delta ^ (5 - ?1) ][1 2 3 4 5]



        set s sum (map * dd encounters_memory)
        let w_t []
        (foreach encounters_memory dd
          [ [a_var b_var]->
            ifelse (a_var > 0) [set w_t lput (a_var * b_var) w_t][set w_t lput 1 w_t]
        ])

        set subjective-risk (s + alpha) / (sum w_t + alpha + beta)
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
to setup-spatially-clustered-network                                       ;to create a network of farmers  ;distance !!!!!Cite Netlogo library!!!
  let num-links (average-node-degree * Number-of-Farmers) / 2
  while [count links < num-links ]
  [
    ask one-of farmers
    [
      let choice (min-one-of (other farmers with [not link-neighbor? myself])[distance myself])
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
      set pcolor farmer_owner * 10
      if N_attacks_here = 1 [set pcolor (farmer_owner / Number-of-Farmers) * 15]
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
 file-open (word N_run "-" (word N "-" (word distance-btw-households "-" (word average-node-degree "-" (word damage "-" (word w1 "-" (word movement_radius (word "B.txt"))))))))

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
to write-timeseries-data   ;;;add risk perception to the output
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

    csv:to-file (word "TS_attacks4-14" "-" (word N_run "-" (word farm-size "-" (word N "-" (word distance-btw-households "-" (word average-node-degree "-" (word damage "-" (word w1 ".csv")))))))) ppcsv
    csv:to-file (word "TS_income4-14"  "-" (word N_run "-" (word farm-size "-" (word N "-" (word distance-btw-households "-" (word average-node-degree "-" (word damage "-" (word w1 ".csv")))))))) ICcsv
    csv:to-file (word "TS_availability4-14"  "-" (word N_run "-" (word farm-size "-" (word N "-" (word distance-btw-households "-" (word average-node-degree "-" (word damage "-" (word w1 ".csv")))))))) Dcsv
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
@#$#@#$#@
GRAPHICS-WINDOW
197
10
558
372
-1
-1
3.5
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
22
205
86
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
100
17.0
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
0.1
4
0.9
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
100.0
1
1
farmers
HORIZONTAL

CHOOSER
684
29
857
74
Color_Landscape
Color_Landscape
"Quality Agro" "Quality for wildlife" "Attacks" "Fenced patches" "objective probability of occupancy" "farms" "EU"
0

SLIDER
13
20
185
53
distance-btw-households
distance-btw-households
3
100
20.0
1
1
NIL
HORIZONTAL

BUTTON
87
239
153
272
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
921
342
1162
489
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
0.73
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
50.0
1
1
NIL
HORIZONTAL

PLOT
673
469
920
619
average p_occ
NIL
NIL
0.0
10.0
0.0
0.001
true
true
"" ""
PENS
"pen-1" 1.0 0 -7500403 true "" "if ticks > 1 [plot mean [p_occ_farm] of farmers]"

SLIDER
10
125
182
158
average-node-degree
average-node-degree
0
10
3.0
1
1
NIL
HORIZONTAL

TEXTBOX
878
100
1646
430
                    Landscape visualization\n\"Quality Agro\": Tones of green to represent the quality the patch for agriculture. Ligher tones for more productive patches\n\n\"Encounters\": To show the when a human-wildlife interaction occured in the patches with agriculture production.\n\n\"Fenced patches\": To  show the state of the exclussion using blue tones. Darker for newer (that is D!=0). Lighter tones represent older or not fence at all (D=1).\n\n\"Objective probability of occupancy\": To show the true probability of an attack. darker tones for higher probability.\n\n\"Farms\": Each color represents the sites that belong to a farmer. \n\nGreen patches represent the area not occupied by farmers (Forest land)
12
0.0
1

SWITCH
686
175
858
208
social-influence
social-influence
0
1
-1000

PLOT
673
313
921
463
Patches with less suitability for wildlife
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
19
440
191
473
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
19
477
191
510
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
685
121
869
166
landscape_scenario
landscape_scenario
"mix Landscape" "protected-area-gradient"
0

CHOOSER
685
75
857
120
topology
topology
"random" "spatially-clustered"
1

BUTTON
87
205
153
238
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
198
410
370
443
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
198
377
372
410
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
21
512
193
545
delta
delta
0
2
0.7
0.1
1
NIL
HORIZONTAL

INPUTBOX
200
485
355
545
time_simulation
1000.0
1
0
Number

MONITOR
401
497
660
542
NIL
precision mean [subjective-risk] of farmers 2
17
1
11

SLIDER
195
444
367
477
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
684
244
856
277
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
383
387
555
420
movement_radius
movement_radius
1
10
10.0
1
1
NIL
HORIZONTAL

SLIDER
374
428
546
461
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
## WHAT IS IT?
This model simulates a group for farmers and their farmland where they produce crops. This production is reduced when they suffer detrimental encounters with a wildlife population. Farmers can reduce the risk of encounters by excluding them. This exlussion reduces the suitability of the patches to support wildlife. Farmers must decide whether or not to invest time in producing and excluding across their land. 
Each farmer agent calculates an expected economic return (or income) per cell by producing crops and expluding wildlife. This decisions are made considering the subjective risk of encounters. This subjective risk depends on past encounters and on the perception of risk from other farmers in the community. The community of farmers passes information about this risk throught in a social network. 
The model evalautes how this social network, by disturbing the objetive probability of encounters, influecnes the decision of the farmers and the spatial pattern on the suitability of area to support wildlife and on the overal income of the population of farmers.
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
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="vary_demage_v61" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - suitability] of patches with [farmer_owner &gt; 0]</metric>
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
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="distance_btw_houses_V61" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>sum [domain] of patches with [farmer_owner &gt; 0]</metric>
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
      <value value="60"/>
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
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
  </experiment>
  <experiment name="prices_V61" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>sum [domain] of patches with [farmer_owner &gt; 0]</metric>
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
    <enumeratedValueSet variable="damage">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="N_run" first="1" step="1" last="10"/>
  </experiment>
  <experiment name="links_V61" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>sum [domain] of patches with [farmer_owner &gt; 0]</metric>
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
      <value value="0.5"/>
      <value value="0.9"/>
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
      <value value="50"/>
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
      <value value="10"/>
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
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="spatialPattern_v61" repetitions="1" runMetricsEveryStep="false">
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
      <value value="5"/>
      <value value="10"/>
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
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N_run">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="w1">
      <value value="0.1"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decay">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Farm_size_V2" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>sum [1 - suitability] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [tot_income] of farmers</metric>
    <metric>sum [total_attacks] of farmers</metric>
    <metric>A</metric>
    <metric>mean [p_occ] of patches with [farmer_owner &gt; 0]</metric>
    <metric>mean [subjective-risk] of farmers</metric>
    <enumeratedValueSet variable="Number-of-Farmers">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-btw-households">
      <value value="13"/>
    </enumeratedValueSet>
    <steppedValueSet variable="farm-size" first="10" step="10" last="100"/>
    <enumeratedValueSet variable="landscape_scenario">
      <value value="&quot;mix Landscape&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ave_yield_ppatch">
      <value value="28"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-influence">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="delta">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aspirations">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="damage">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="operational_costs">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement_radius">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
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
