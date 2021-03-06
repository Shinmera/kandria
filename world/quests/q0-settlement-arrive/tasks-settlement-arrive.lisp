(:name talk-to-catherine
 :title "Talk to Catherine"
 :description NIL
 :invariant T
 :condition all-complete
 :on-activate (arrive)
 :on-complete NIL)

;; TODO: the last player emotion in the choices is the one that will render; have it change per highlighted choice?
;; TODO: replace (Lie) with [Lie] as per RPG convention, and to save parenthetical expressions for asides - currently square brackets not rendering correctly though
;; REMARK: ^ Does \[Lie\] not work?
(quest:interaction :name arrive :interactable catherine :dialogue "
~ catherine
| (:cheer) Tada! Here we are!
| What do you think...?
~ player
- It's a ruined city.
  ~ catherine
  | (:excited) Yep! It's home.
- It's nice.
  ~ catherine
  | (:excited) I knew you'd love it!
- (Lie) It's nice.
  ~ catherine
  | (:excited) I knew you'd love it!
- You live here?
  ~ catherine
  | (:excited) Yep! Pretty amazing, huh?
~ catherine
| And come look at this - I guarantee you won't ever have seen anything like it!
! eval (activate 'field)
! eval (lead 'player 'farm-view 'catherine)
! eval (walk-n-talk 'walk)
")
 
;; TODO: doesn't always play these, if they get interrupted by lead reminder - and if they don't complete, this task never completes?
;; REMARK: ^ You can change the task condition from ALL-COMPLETE to a check that only checks the required interactions, like (complete-p 'arrive 'field)
(quest:interaction :name walk :interactable catherine :dialogue "
! eval (complete 'walk)
--
~ catherine
| (:normal) Living on the surface is even harder than in the caves.
")

;; TODO: force complete 'walk to ensure this whole task completes, even if walk-talk interrupted?
;; REMARK: It's confusing that you don't talk to catherine and instead have to find some hidden trigger volume.
;;         It would be better if this was activated on catherine as soon as the player walks into the farm
;;         by using a story-trigger, or even just directly activating it via an interaction-trigger.
(quest:interaction :name field :interactable farm-view :dialogue "
~ catherine
| (:excited) What'd I tell you? Amazing, right?!
~ player
- What I am looking at?
  ~ catherine
  | (:excited) They're crops! We're growing crops - in the desert!
  | (:normal) ...
  | (:disappointed) Well don't look too excited. This is a real feat, believe me.
- How did you manage this?
  ~ catherine
  | (:normal) Don't ask me - I'm just an engineer. Though I did help install the irrigation.
  | Needless to say, growing crops in the desert isn't easy.
  | (:excited) Heh, I knew you'd be impressed.
- I've seen these before. Lots of times.
  ~ catherine
  | (:normal) Oh...? From the old world? Do you remember? I bet they had loads of plantations.
  ~ player
  | (:thinking) I can't recall exactly. But I know I've seen crops like these before.  
  ~ catherine
  | (:excited) Whoa, that's so cool. I wish I could have seen that too.
~ catherine
| (:concerned) Erm... hang on a second. Where is everyone?
| This isn't the welcome I was expecting.
~ player
- Is something wrong?
  ~ catherine
  | (:concerned) Well, I just reactivated an android...
  | I thought they'd all be here to see you.
- What were you expecting?
  ~ catherine
  | (:concerned) I don't know...
  | Though I just reactivated an android... I guess I thought everyone would be here to see you.
- Is it me?
  ~ catherine
  | (:concerned) You?... No of course not.
  | Well... I mean, I think you're amazing - a working android from the old world!
  | But not everyone has fond tales to tell about androids, I guess. Their loss though.
~ catherine
| (:concerned) We'd better find Jack. He'll be in Engineering.
! eval (activate 'find-jack)
! eval (lead 'player 'jack (unit 'catherine))
")
;; learn Jack's name for the first time
;; TODO catherine confused: Erm... hang on a second. Where is everyone?

#| CUT DIALOGUE FOR TESTING EASE



|#


#|
Tutorial/prologue mission beats that have occurred before this scene:
Alex planted the android there on behalf of the enemy faction (traitor), knowing that Catherine could repair it for them
Rogue robots on behalf of the enemy faction then tried to ambush and claim the android, but you beat them off
Catherine, non-the-wiser to Alex's betrayal, returns to the settlement with the android
(Meanwhile Alex has gone off doing hunter duties)
(The enemy faction timed the android planting with their sabotage of the water pipes, so that Catherine would be away at a critical time)
(Catherine has determined android is a "she")
(Catherine introduced herself by name, and established that the android doesn't have a name)
(Catherine learns the stranger doesn't have a home)
|#
