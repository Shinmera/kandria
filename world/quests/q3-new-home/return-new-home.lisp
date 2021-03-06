(:name return-new-home
 :title "Return to Jack"
 :description NIL
 :invariant T
 :condition all-complete
 :on-activate (new-home-return)
 :on-complete NIL)

;; enemies on this quest will be world NPCs, not spawned for the quest
;; REMARK: The mansplain part feels like it touches on current real-life political commentary and sticks out too much to me.
(quest:interaction :name new-home-return :interactable jack :dialogue "
~ jack
| You're back. How'd it go?
~ player
- How do you think it went?
  ~ jack
  | I admit it was a thankless task, but I thought there might at least be somewhere we could go.
- Not good news I'm afraid.
  ~ jack
  | Fuck.
- You're stuck here.
  ~ jack
  | Fuck.
~ jack
| (:thinking) Fi ain't gonna like this. I suppose she'd better hear it from me, rather than from some stone-cold android.
| (:annoyed) Thanks for your help, but it's my problem now.
| You want something for your labour?
~ player
- Yes please.
  ~ jack
  | Figures. Here ya go.
  ! eval (store 'parts 10)
  < explain
- That's the normal etiquette, isn't it?
  ~ jack
  | I guess so. Here ya go.
  ! eval (store 'parts 10)
  < explain
- Not from you.
  ~ jack
  | Suit yerself.
  < continue
- No thanks.
  ~ jack
  | Suit yerself.
  < continue

# explain
~ jack
| You can trade with those spare parts.
~ player
- Thanks for the mansplain.
  ~ jack
  | You're welcome. Wait what?...
- Understood.
< continue

# continue
? (complete-p 'q2-seeds)
| | (:normal) Oh, Cathy wants a word too.
| | (:annoyed) Know that my threat still stands if you touch her.
| ! eval (activate 'sq-act1-intro)
|?
| ? (not (active-p 'q2-seeds))
| | | (:normal) Speaking o' Fi, she wants to talk to you. Not a word about the scouting fail though, alright?
|   
| | (:normal) Don't let me be the one to help you out, either, but I heard Sahil was back.
| | His caravan is down in the Midwest Market, beneath the Hub.
| | I don't know what opposition you've faced scouting around, but you might wanna stock up.
| | I hear even androids ain't indestructible...
| ! eval (setf (location 'trader) 'loc-trader)
| ! eval (activate 'trader-arrive)
")

#|



|#
