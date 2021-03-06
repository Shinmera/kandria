(:name leak-first
 :title "Find the first leak"
 :description NIL
 :invariant T
 :condition all-complete
 :on-activate (leak-1)
 :on-complete NIL)

;; enemies on this quest will be world NPCs, not spawned for the quest
(quest:interaction :name leak-1 :interactable leak-1 :dialogue "
~ player
| //There's a hole in the pipe - probably caused by duress where it bends around this corner.//
? (not (var 'first-leak))
| | //I ignite the torch from the index finger on my right hand.//
| | [(var 'q1-weld-burn) (:embarassed) //This time I enable the UV filters on my cameras.// | (:normal) //I enable the UV filters on my cameras.//]
| | (:normal) //Weld complete.//
| ? (have 'walkie-talkie)
| | | //I turn on the walkie-talkie. It's heavy for such a simple piece of technology.//
|  
| | Catherine, I've sealed one of the leaks. [(have 'walkie-talkie) Over.|]
| ~ catherine
| | Great work - the pressure is much better already.
| | Keep going - let me know if you hit any trouble. [(have 'walkie-talkie) Over and out.|]
| ! eval (setf (var 'first-leak) T)
|?
| | //Weld complete.//
? (complete-p 'leak-second 'leak-third)
| ~ player
| | Catherine, I think I got the last leak. [(have 'walkie-talkie) Over.|]
| ~ catherine
| | (:cheer) You did - pressure is returning! That's a job well done. [(have 'walkie-talkie) Over.|]
| | (:normal) Any sign of saboteurs? [(have 'walkie-talkie) Over.|]
| ~ player
| - No, all clear.
|   ~ catherine
|   | That's what I like to hear.
| - It was all subsidence, or wear and tear.
|   ~ catherine
|   | Oh man, you could probably stand not to hear more about landslides... Sorry!
| ~ catherine
| | (:excited) Hurry back, I've got a little something for you. [(have 'walkie-talkie) Over and out.|]
| ! eval (activate 'return-leaks)
")
;; TODO: how does FFCS communicate with Catherine? Catherine still needs to use walkie and "over"? Yes, but FFCS removes need for "over" as it can control things dynamically remotely
;; UNUSED: and a sprawl of soil and stones - subsidence caused this.