breed [dogs dog]
breed [packs pack]
breed [disperser-groups disperser-group]

dogs-own
 [
   age
   sex
   status
   my-pack
   my-disperser-group
 ]
 
packs-own [pack-members]

disperser-groups-own
 [
   sex
   group-members
 ]

globals 
 [
   initial-num-packs
   initial-mean-pack-size
   years-to-simulate
   ; carrying-capacity           Moved to slider
   ; disperser-meet-rate         Moved to slider
   
   ; See "setup-repro-logistic" for explanation of these:
   repro-logistic-A
   repro-logistic-B
   repro-prob          ; Annual probability of a pack reproducing
   
   ; See "setup" concerning other parameters distributed in code
 ]
 
to setup


  clear-all
  reset-ticks
  
  ; First, initialize global parameters
  ; Note that mortality parameters are coded in the procedure "do-mortality"
  ; Parameters for probability of packs reproducing are in "setup-repro-logistic"

  set initial-num-packs 10
  set initial-mean-pack-size 5
  set years-to-simulate 100
  
  ; set up the logistic function used to model reproduction probability
  setup-repro-logistic
  
  ; Now create the packs and their dogs
  create-packs initial-num-packs
   [
     ; set a location just for display
     setxy random-xcor random-ycor
     set shape "box"  ; a pack-age
     
     ; create the pack's dogs
     let num-dogs random-poisson initial-mean-pack-size
     
     hatch-dogs num-dogs
      [
        ; first, set display variables
        set shape "cow"  ; close enough
        set heading random 360
        fd 1
        
        ; now assign dog state variables
        if-else random-bernoulli 0.5
         [set sex "male"]
         [set sex "female"]
         
        set age random 7
        
        set-my-status  ; a dog procedure that sets their status from age
        
        set my-pack myself  ; assign dog's pack to the pack that hatched it
      ] ; end of hatch-dogs
      
     ; Initialize the pack's agentset containing its dogs
     set pack-members dogs with [my-pack = myself]
     ; show count pack-members  ; Temporary test output
      
     ; now select the alpha dogs
     update-pack-alphas    ; a pack procedure that assigns alpha status
      
   ] ; end of create-packs
   
  ; Prepare an output file for testing and analysis

  if (file-exists? "PackTestOutput.csv") 
  [carefully [file-delete "PackTestOutput.csv"] 
  [print error-message]]
  file-open "PackTestOutput.csv"
  
  ; Now write file headers
  file-type "Pack-id,"
  file-type "Tick,"
  file-type "#-members,"
  file-type "#-alphas,"
  file-type "#-subordinates,"
  file-type "#-yearlings,"
  file-type "#-pups,"
  file-print "Output from individuals"
  
  file-close

   ; And...output the initial state
   update-output

end

to go

 tick
 if ticks > years-to-simulate [stop]
 
 ; First, age and status updates
 ask dogs
  [
    set age age + 1
    set-my-status
  ]
 
 ; test-packs
 
 ask packs [update-pack-alphas]
 
 ; test-packs
 
 ; Second, reproduction. This first requires updating the probability
 ; of a pack reproducing, which depends on the population before reprod. starts
 update-repro-prob
 ask packs [reproduce]
 
 ; test-packs    ; An optional test output
 
 ; Third, dispersal
 ask packs [disperse]
 
 ; test-packs   ; Use this output again here to test disperse method
 
 ; Fourth, mortality
 ask dogs [do-mortality]
 
 ; Fifth, mortality of collectives
 ask packs [do-pack-mortality]
 ask disperser-groups [if count group-members = 0 [die]]
 
 ; Sixth, pack formation
 ask disperser-groups [do-pack-formation]
 
 ; Finally, produce output
 update-output

end


to reproduce  ; a pack procedure

  ; First, stop if there is not an alpha male and female
  if count pack-members with [status = "alpha"] != 2 [stop]
  
  ; Now determine whether to reproduce and do so
  ; The global variable "repro-prob" is updated in update-repro-prob
  if random-bernoulli repro-prob
    [
     ; create the pups
     let num-pups random-poisson 7.9
     
     ; show word "Hatching " num-pups  ; Test output
     hatch-dogs num-pups
      [
        ; display it
        set shape "cow"  ; close enough
        set heading random 360
        fd 1
        
        ; now assign state variables
        if-else random-bernoulli 0.55
         [set sex "male"]
         [set sex "female"]
         
        set age 0
        
        set-my-status
        
        set my-pack myself
        
        ; and add the pup to the pack
        ask myself 
         [
           set pack-members (turtle-set pack-members myself)
         ]
      ]  ; End of hatch-dogs
      
    ]  ; End of random-bernoulli
  
end

to disperse   ; a pack procedure

  ; First, identify the subordinates and stop if there are none
  let my-subordinates pack-members with [status = "subordinate"]
  if not any? my-subordinates [stop]
  
  ; Now check females
  if count my-subordinates with [sex = "female"] = 1
   [
     if random-bernoulli 0.5
     [create-disperser-group-from my-subordinates with [sex = "female"] ]
   ]
  
  if count my-subordinates with [sex = "female"] > 1
   [create-disperser-group-from my-subordinates with [sex = "female"] ]
  
  ; And check males
  if count my-subordinates with [sex = "male"] = 1
   [
     if random-bernoulli 0.5
     [create-disperser-group-from my-subordinates with [sex = "male"] ]
   ]
  
  if count my-subordinates with [sex = "male"] > 1
   [create-disperser-group-from my-subordinates with [sex = "male"] ]
  
end


to do-mortality

  ; Mortality probabilities are coded here

  if status = "disperser"
   [ if random-bernoulli 0.44 [die] ]

  if status = "yearling"
   [ if random-bernoulli 0.25 [die] ]

  if age >= 2
   [ if random-bernoulli 0.2 [die] ]
   
  if status = "pup"
   [ if random-bernoulli 0.12 [die] ]
  
end


to do-pack-mortality   ; pack procedure

  if count pack-members = 0 [die]
  
  ; If a pack has only pups, the pups and the pack die
  if count pack-members with [status != "pup"] = 0
   [
     ask pack-members [die]
     die
   ]

end


to do-pack-formation  ; disperser-group procedure

  ; A little defensive programming
  if count group-members < 1
    [ user-message "In do-pack-formation: Disperser group is empty!"]

  ; First, determine randomly how many groups are encountered.
  ; This can be zero, or more than the number of other packs (because you can
  ; meet the same pack more than once).
  let num-groups-met random-poisson (count other disperser-groups * disperser-meet-rate)
  ; show (word count other disperser-groups " " num-groups-met) ; Temporary test output
  
  ; Now repeat the pack formation process for each group met.
  ; This loop stops if a pack is formed because the disperser group executing it dies.
  repeat num-groups-met
   [
    ; identify another disperser group
    let sniffees one-of other disperser-groups
    
    ; identify its and our former pack
    let our-former-pack [my-pack] of one-of group-members
    let their-former-pack [my-pack] of one-of [group-members] of sniffees

    ; Now decide whether to merge into a pack
    if ([sex] of sniffees != sex) and (our-former-pack != their-former-pack) and (random-bernoulli 0.64)
      [
        ; Create the pack and put the dogs in it
        hatch-packs 1
        [
         set pack-members [group-members] of myself
         ; show count pack-members   ; Temporary test output
         set pack-members (turtle-set pack-members [group-members] of sniffees)
         ; show count pack-members   ; Temporary test output

         ; Display the new pack
         setxy random-xcor random-ycor
         set shape "box"  ; a pack-age

         ; Update the pack member state and display variables
         ask pack-members 
          [
            set my-pack myself
            set status "subordinate"
            set color red
            setxy [xcor] of myself [ycor] of myself
            set heading random 360
            fd 1
          ]
        
         ; Now pick alphas for the pack
         update-pack-alphas
           ; A little defensive programming
           if count pack-members with [status = "alpha"] != 2
             [ user-message "In do-pack-formation: Not 2 alphas in newly formed pack!!"]

        ]
    
       ; Finally, destroy the disperser groups
       ask sniffees [die]
       die     
    ] ; End of "if random-bernoulli 0.64"
    
  ]  ; End of "repeat num-group met"
  
end

to set-my-status  ; a dog procedure

  if status = "disperser" [stop]
  if status = "alpha" [stop]
  
  if age = 0 
   [
     set status "pup"
     set color white
     stop
   ]

  if age = 1 
   [
     set status "yearling"
     set color blue
     stop
   ]

 set status "subordinate"
 set color red

end

to update-pack-alphas ; a pack procedure

  ; This producedure checks whether a pack has alpha males and
  ; females, and if not selects them.
  
  if not any? pack-members with [sex = "female" and status = "alpha"]
   [
     ; show "Selecting new alpha female"   ; Temporary test output
     if any? pack-members with [sex = "female" and status = "subordinate"]
      [
        ask one-of pack-members with [sex = "female" and status = "subordinate"]
         [
          set status "alpha"
          set color yellow
         ]
      ]
   ]
  
  if not any? pack-members with [sex = "male" and status = "alpha"]
   [
     ; show "Selecting new alpha male"   ; Temporary test output
     if any? pack-members with [sex = "male" and status = "subordinate"]
      [
        ask one-of pack-members with [sex = "male" and status = "subordinate"]
         [
          set status "alpha"
          set color yellow
         ]
      ]
   ]

  ; A little defensive programming
  if count pack-members with [status = "alpha"] > 2
   [ user-message "In update-pack-alphas: More than 2 alphas in a pack!!"]

end


to create-disperser-group-from [some-dogs]   ; a pack procedure

  ; First, create the disperser group and put the dogs in it
  hatch-disperser-groups 1
   [
     ; Set disperser group variables
     set group-members some-dogs
     set sex [sex] of one-of some-dogs

     ; Display the group
     set shape "car"  ; Goin' mobile...
     set heading random 360
     fd 2

    ; Now set status of the dispersing dogs
     ask some-dogs
      [
        set my-disperser-group myself
        set status "disperser"
        set color green
      
        ; and display them in a line from the disperser group
        setxy [xcor] of my-disperser-group [ycor] of my-disperser-group
        set heading [heading] of my-disperser-group
        fd 1 + random-float 2
      ]
     
  ] ; End of hatch-disperser-groups
   
    
  ; Finally remove the dispersers from their former pack
  let dogs-former-pack [my-pack] of one-of some-dogs
  ask dogs-former-pack [set pack-members pack-members with [status != "disperser"]]

end


to setup-repro-logistic 
  ; Executed once at setup to build logistic function used to model probability
  ; of packs producing pups, a function of population size N.
  ; Logistic function has value of 0.5 when N is half of carrying capacity,
  ; and 0.1 when N equals the carrying capacity.
  
  let P1 0.5
  let X1 carrying-capacity / 2
  let P2 0.1
  let X2 carrying-capacity
  
  let repro-D ln (P1 / (1 - P1))
  let repro-C ln (P2 / (1 - P2))
  
  set repro-logistic-B (repro-D - repro-C) / (X1 - X2)
  set repro-logistic-A repro-D - (repro-logistic-B * X1)
  
  ; Test code
  ; let delta (X2 - X1) / 10
  ; let test-X X1
  ; let test-Z 0
  ; let test-P 0
  
  ; repeat 11
  ;  [
  ;   set test-Z exp (repro-logistic-A + (repro-logistic-B * test-X))
  ;   set test-P test-Z / (1 + test-Z)
  ;   show (word "X = " test-X " P= " test-P)
    
  ;   set test-X test-X + delta
  ;  ]
 
end


to update-repro-prob

  ; This procedure updates the probability of reproducing (global var. repro-prob),
  ; a function of the total dog population before reproduction starts
  let total-pop count dogs
  
  ; Use the logistic variables initialized during setup
  let logistic-Z exp (repro-logistic-A + (repro-logistic-B * total-pop))
   
  set repro-prob (logistic-Z / (1 + logistic-Z))
  
end


to-report random-bernoulli [probability-true]

  ; First, do some defensive programming to make sure "probability-true"
  ; has a sensible value

  if (probability-true < 0.0 or probability-true > 1.0) 
    [ 
      type "Warning in random-bernoulli: probability-true equals "
      print probability-true
    ]

  report random-float 1.0 < probability-true
 
end


to update-output

  ; Update the population plot
  set-current-plot "Population"
  set-current-plot-pen "Pups"
  plot count dogs with [status = "pup"]

  set-current-plot-pen "Yearlings"
  plot count dogs with [status = "yearling"]

  set-current-plot-pen "Subordinates+alphas"
  plot count dogs with [status = "subordinate" or status = "alpha"]

  set-current-plot-pen "Dispersers"
  plot count dogs with [status = "disperser"]
  
end


to test-packs
  ; A test procedure to check whether packs and individuals
  ; are keeping track of each other. Can be executed at any time.
  ; File headers are written in "setup"
  
  file-open "PackTestOutput.csv"
  
  ; Output from packs
  ask packs
   [
    file-type (word who "," ticks ",")
    file-type (word count pack-members ",")
    file-type (word count pack-members with [status = "alpha"] ",")
    file-type (word count pack-members with [status = "subordinate"] ",")
    file-type (word count pack-members with [status = "yearling"] ",")
    file-type (word count pack-members with [status = "pup"] ",")

    ; And output from pack members
    ask pack-members
      [
        file-type (word status ",")
      ]
    
    ; Wrap it up with a line-end
    file-print ","
     
   ]
  
  file-close

end
@#$#@#$#@
GRAPHICS-WINDOW
221
10
561
371
16
16
10.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
15
10
86
43
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
15
51
78
84
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
15
92
78
125
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
12
374
562
524
Population
Year
Number alive
0.0
100.0
0.0
10.0
true
true
"" ""
PENS
"Pups" 1.0 0 -16777216 true "" ""
"Yearlings" 1.0 0 -13345367 true "" ""
"Subordinates+alphas" 1.0 0 -2674135 true "" ""
"Dispersers" 1.0 0 -10899396 true "" ""

SLIDER
14
172
186
205
disperser-meet-rate
disperser-meet-rate
0
2
1
.1
1
NIL
HORIZONTAL

MONITOR
17
251
122
296
Number of packs
count packs
0
1
11

MONITOR
16
309
182
354
Number of disperser groups
count disperser-groups
0
1
11

SLIDER
14
214
189
247
carrying-capacity
carrying-capacity
10
200
60
5
1
NIL
HORIZONTAL

@#$#@#$#@
# THE WILD DOG MODEL

## MODEL DESCRIPTION (ODD)

This model was produced by S. Railsback and V. Grimm for the book _Agent-Based and Individual-Based Modeling: A Practical Introduction_.

Here and in Section 16.4, only the "Overview" part of an ODD model description is provided, but with all the detail needed to fully implement the model. Writing the full ODD description is an exercise of Chapter 16.

### PURPOSE

This is a simplified, hypothetical version of a model designed to evaluate management actions to enhance the persistence of African wild dogs, an endangered species protected in several preserves in South Africa. (The original model is described by: Gusset, et al. 2009. Dogs on the catwalk: modelling re-introduction and translocation of endangered wild dogs in South Africa. Biological Conservation 142:2774-2781.)

The purpose of the model is to evaluate how the persistence of a wild dog population depends on (a) the reserve's carrying capacity, as represented by the parameters relating the probability of a pack reproducing to the total population, (b) the ability of dispersing dogs to find each other, and (c) the mortality risk of dispersing dogs. Measures of "persistence" include the average number of years (over a number of replicate simulations) until the population is extinct, and the percent of simulations in which the population survives for at least 100 years. 

As a NetLogo exercise, the model's purpose is to demonstrate the use of breeds to represent collectives. The model also illustrates stochastic modeling techniques.
   
### ENTITIES, STATE VARIABLES, AND SCALES

The model includes three kinds of agent: dogs, dog packs, and disperser groups. Dogs have state variables for age in years, sex, the pack or disperser group they belong to (to keep track of which dogs belong to which pack), and social status. The social status of a dog can be (a) "pup", meaning its age is less than one; (b) "yearling", with age between 1 and 2; (c) "subordinate", meaning age is greater than 2 but the dog is not an alpha; (d) "alpha", meaning the dominant individual of its sex in a pack; and (e) "disperser", meaning the dog currently belongs to a disperser group, not a pack. 

Dog packs have no state variables except for a list (or, in NetLogo, an agentset) of the dogs belonging to the pack. Disperser groups have a state variable for sex (all members are of the same sex) and a list of the member dogs.

The time step is one year. The model is non-spatial: locations of packs and dogs are not represented. However, its parameters reflect the size and resources of the Hluhluwe-Imfolozi Park. 
   
### PROCESS OVERVIEW AND SCHEDULING

The following actions are executed once per time step, in this order.

  * Age and social status update:   
    * The age of all dogs is incremented. Their social status variable is updated according to the new age.  

    * Each pack updates its alpha males and females. If there is no alpha of a sex, a subordinate of that sex is randomly selected (if there is one) and its social status variable set to "alpha". 

  * Reproduction. Packs determine how many pups they produce, using these rules:  

    * If the pack does not include both an alpha female and alpha male, no pups are produced.  
    * Otherwise, the probability of a pack producing pups depends on the total number of dogs in the entire population at the current time step (N). (N does not include any pups already produced in the current time step.) The probability of a pack reproducing (P) is modeled as a logistic function of N, and the parameters of this logistic function depend on the carrying capacity (maximum sustainable number of dogs) of the reserve. P has a value of 0.5 when N is half the carrying capacity and a value of 0.1 when N equals the carrying capacity. The carrying capacity is 60 dogs. (See the programming note below concerning logistic functions.)  
    * If the pack reproduces, the number of pups is drawn from a Poisson distribution that has a mean birth rate (pups per pack per year) of 7.9. Sex is assigned to each pup randomly with a 0.55 probability of being male. Pup age is set to 0.

  * Dispersal. Subordinate dogs can leave their packs in hopes of establishing a new pack. These "dispersers" form disperser groups, which comprise one or more subordinates of the same sex that came from the same pack. Each pack follows these rules to produce disperser groups:  
    * If a pack has no subordinates, then no disperser group is created.  
    * If a pack has only one subordinate of its sex, it has a probability of 0.5 of forming a disperser group.  
    * If a pack has more than one subordinate of the same sex, they always form a disperser group.  
    * Dogs that join a disperser group no longer belong to their original pack, and their social status variable is set to "disperser".

  * Dog mortality. Mortality is scheduled before pack formation because mortality of dispersers is high. Whether or not each dog dies is determined stochastically using the following probabilities of dying: 0.44 for dispersers, 0.25 for yearlings, 0.2 for subordinates and alphas, and 0.12 for pups.

  * Mortality of collectives. If any pack or dispersal group has no members, it is removed from the model. If any pack contains only pups, the pups die and the pack is removed.

  * Pack formation. Disperser groups may meet other disperser groups, and if they meet a disperser group of the opposite sex and from a different pack, the groups may or may not join to form a new pack. This process is modeled by having each disperser group execute the following steps. The order in which disperser groups execute this action is randomly shuffled each time step.  
    * Determine how many times another disperser group is met (variable num-groups-met). Num-groups-met is modeled as a Poisson process with the rate of meeting (mean number of times per year that another group is met) equal to the number of other disperser groups times a parameter for the mean number of times that any two groups meet within one year. This meeting rate parameter can potentially have any value of 0.0 or higher (it can be greater than 1) but is given a value of 1.0. The following steps are repeated up to num-groups-met times, stopping if the disperser group selects another to join.  
    * Randomly select one other disperser group. It is possible to select the same other group more than once.  
    * If the other group is of the same sex, or originated from the same pack, then do nothing more.  
    * If the other group is of the opposite sex, then there is a probability of 0.64 that the two groups join to form a new pack. If they do not join, nothing else happens.  
    * If two disperser groups do join, a new pack is created and all the dogs in the two groups are its members. The alpha male and female are chosen randomly; all other members are given a social status of "subordinate". The two disperser groups are immediately removed so they are not available to merge with remaining groups.    

### Initialization 

The model is initialized with 10 packs and no disperser groups. The number of dogs in each initial pack is drawn from a Poisson distribution with mean of 5 (even though this is not a Poisson process). The sex of each dog is set randomly with equal probabilities. The age of individuals is drawn from a uniform integer distribution between 0 and 6. Social status is set according to age. The alpha male and female of each pack are selected randomly from among its subordinates; if there are no subordinates of a sex, then the pack has no alpha of that sex. 
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
NetLogo 5.0RC4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Meet-rate sensitivity" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>count dogs</metric>
    <steppedValueSet variable="disperser-meet-rate" first="0" step="0.2" last="2"/>
    <enumeratedValueSet variable="carrying-capacity">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Carrying-capacity-sensitivity" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>ticks</metric>
    <steppedValueSet variable="carrying-capacity" first="10" step="10" last="120"/>
    <enumeratedValueSet variable="disperser-meet-rate">
      <value value="1"/>
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
