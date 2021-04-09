(:name trade-trader
 :title "Talk to Sahil"
 :description NIL
 :invariant T
 :condition NIL
 :on-activate (trade-with-trader)
 :on-complete NIL)
 
 ;; TODO Sahil currently has limited stock in this act - it will not refresh until the next act, so once it's gone it's gone (set in this quest's meta)
 ;; TODO use global vars instead of magic numbers for cost of packs
(quest:interaction :name trade-with-trader :interactable trader :repeatable T :dialogue "
~ trader
| Assalam Alaikum!
? (< 80  (health player))
| | [? You look well, Stranger! | And how robust you're looking today! | I don't think I've seen you looking more radiant.]
|? (< 50  (health player))
| | [? Have you been fighting, Stranger? | Something's different - you're missing your usual refined appearance. | Let me guess - you've been pounding rogues again?]
|?
| | [? Though I think you've seen better days... | You look like you could really use my help today. | You look like you've been dragged throgh the desert backwards... | Forgive me for prying, but you're all scratched and scuffed - anything I can do?]
! label shop
~ player
- I'd like to trade.
  ~ trader
  | [? That's what I like to hear! | Yes, sir! | And so would I! | That's the spirit! | You got it.]
  ~ player
  - //Buy//
    ! label buy
    ~ player
    - //Small HP (I have {(item-count 'small-health-pack)}) - 4$//
      ? (and (<= 4 (item-count 'parts)) (< 0 (var 'small-health-qty)))
      | ! eval (retrieve 'parts 4)
      | ! eval (store 'small-health-pack 1)
      | ! eval (setf (var 'small-health-qty) (- (var 'small-health-qty) 1))
      | ? (= 0 (var 'small-health-qty))
      | | ~ trader
      | | < last-one
      | < buy
      |? (> 4 (item-count 'parts))
      | < cannot-afford
      |?
      | < out-of-stock
    - //Medium HP (I have {(item-count 'medium-health-pack)}) - 10$//
      ? (and (<= 10 (item-count 'parts)) (< 0 (var 'medium-health-qty)))
      | ! eval (retrieve 'parts 10)
      | ! eval (store 'medium-health-pack 1)
      | ! eval (setf (var 'medium-health-qty) (- (var 'medium-health-qty) 1))
      | ? (= 0 (var 'medium-health-qty))
      | | ~ trader
      | | < last-one
      | < buy
      |? (> 10 (item-count 'parts))
      | < cannot-afford
      |?
      | < out-of-stock
    - //Large HP (I have {(item-count 'large-health-pack)}) - 20$//
      ? (and (<= 20 (item-count 'parts)) (< 0 (var 'large-health-qty)))
      | ! eval (retrieve 'parts 20)
      | ! eval (store 'large-health-pack 1)
      | ! eval (setf (var 'large-health-qty) (- (var 'large-health-qty) 1))
      | ? (= 0 (var 'large-health-qty))
      | | ~ trader
      | | < last-one
      | < buy
      |? (> 20 (item-count 'parts))
      | < cannot-afford
      |?
      | < out-of-stock
    - I'm done.
      < shop
  - //Sell//
    ! label sell
    ~ player
    - [(have 'small-health-pack) //Small HP for 2$ (I have {(item-count 'small-health-pack)})//|]
      ! eval (retrieve 'small-health-pack 1)
      ! eval (store 'parts 2)
      < sell
    - [(have 'medium-health-pack) //Medium HP for 5$ (I have {(item-count 'medium-health-pack)})//|]
      ! eval (retrieve 'medium-health-pack 1)
      ! eval (store 'parts 5)
      < sell
    - [(have 'large-health-pack) //Large HP for 10$ (I have {(item-count 'large-health-pack)})//|]
      ! eval (retrieve 'large-health-pack 1)
      ! eval (store 'parts 10)
      < sell
    - [(have 'walkie-talkie) //Walkie-talkie for 150$//|]
      ! eval (retrieve 'walkie-talkie 1)
      ! eval (store 'parts 150)
      ~ trader
      | Hey, where'd you get that? These things are almost priceless.
      | Not for old Sahil, of course.
      < sell
    - [(have 'mushroom-bad-1) //Black knights ({(item-count 'mushroom-bad-1)}) for {(* (item-count 'mushroom-bad-1) 20)}$//|]
      ! eval (store 'parts (* (item-count 'mushroom-bad-1) 20))
      ! eval (retrieve 'mushroom-bad-1 (item-count 'mushroom-bad-1))
      ~ trader
      | It's true, black knights are poisonous to consume.
      | But there are some in the Valley who... Let's just say they have other uses for them.
      < sell
    - //Nothing to sell//
      < shop
  - I changed my mind.
    < changed-mind
- Can we talk.
  ~ trader
  | [? Of course, habeebti - always. | We can indeed. | What's on your mind? | I love to chat.]
  ! label talk
  ? (not (complete-p 'q4-find-allies))
  | ~ player
  | - What's your story?
  |   ~ trader
  |   | A long and sad one I'm afriad... Like most people's.
  |   | I used to hang with the Wraw too, believe it or not.
  |   | I got out too, only with my caravan rather than a vendetta.
  |   | And now I tour the settlements, trading, making ends meet - and making things too!
  |   < talk
  | - What do you make of this place?
  |   ~ trader
  |   | The Noka? They're a nice bunch, what can I say?
  |   | Fi's a good person, which is rare in these parts.
  |   | They broke out on their own, had enough of that Wraw bullshit.
  |   | Can't blame 'em. It was brave. It might also prove stupid though, we'll see.
  |   < talk
  | - Catherine said you were later than expected...
  |   ~ trader
  |   | Yeah, those damn rogues were prowling about.
  |   | Don't get me wrong, I can handle myself.
  |   | But it's not easy when you're pulling your own caravan.
  |   ~ player
  |   | You pull your own caravan?
  |   ~ trader
  |   | Well no other nadhil is going to do it!
  |   | I used to have an ox, believe or not... Ha, an ox, in these parts! It's hard to imagine.
  |   | Didn't last long after the wolves got at her throat though. Poor Celina.
  |   < talk
  | - I changed my mind.
  |   < changed-mind
- I need to go.
! label leave
~ trader
| [? See you later habeebti. | You take it easy. | Goodbye for now. | Take care. Masalamah! | Goodbye! And if you ever change your mind about parting with that sword of yours... I know, I know.]

# last-one
~ trader
| That was the last of my stock on that item, for now.
< buy

# cannot-afford
~ trader
| Oh, looks like you can't afford that one. Sorry!
< buy

# out-of-stock
~ trader
| All out of stock on that one I'm afriad. Sorry, habeebti.
< buy

# changed-mind
~ trader
| [? Happens to the best of us. | As you wish. | Don't worry about it.]
< shop
")
;; nadhil = bastard (Arabic)
;; TODO show currency while in shop UI
;; TODO: flesh out with Sahil questions relevant to current plot points - confidente, as a fellow outsider?

#| TODO: when get scrolling options, add to buy menu:
    - I want to sell.
      < sell
    - I'm done.
      < shop
    - //I need to go.//
      < leave

Also leave to Talk options
  | - I need to go.
  |   < leave
|#

#| TODO when get scrolling options, restore to talk menu:

  | - Do you know about finding a computer?
  |   ~ trader
  |   | A computer? Now there's a word you don't hear anymore.
  |   | Does Catherine want to play one of those video games from the old world I was telling her about?
  |   | You remember them, right?
  |   ~ player
  |   - Sure, games were fun.
  |     ~ trader
  |     | You betcha! Boy do I miss the internet.
  |   - They were a new artform, sadly lost.
  |     ~ trader
  |     | Well said, Stranger. Well said.
  |   - They used similar technology to my own. I admired that.
  |     ~ trader
  |     | Indeed, there was a lot to admire - especially for a tech-head like me.
  |   ~ trader
  |   | But no, no one told me anything about a computer. Which is good, because working ones are impossible to find.
  |   < talk
  | - Do you like androids?
  |   ~ trader
  |   | Ah, you've had a warm welcome, have you?
  |   | Listen, it's nothing personal. It's just everyone has heard the stories, you know?
  |   | It's always androids this, androids that... Like a race of servile machines could destroy the world!
  |   | No offence. It's haraa, that's what it is.
  |   ~ player
  |   | So what did destroy the world?
  |   ~ trader
  |   | I don't know...
  |   | But what I do know is humanity could stand to take a good long look in the mirror.
  |   < talk

|#

#|
ORIGINAL IMPLEMENTATION IDEA FOR BUY MENU - works
    # buy
    - [(and (<= 4 (item-count 'parts)) (< 0 (var 'small-health-qty))) //Buy a small health pack for 4 scrap parts// | I can't afford 4 scrap parts for a small health pack.|] (stock: (var 'small-health-qty))
      ! eval (retrieve 'parts 4)
      ! eval (store 'small-health-pack 1)
      ! eval (setf (var 'small-health-qty) (- (var 'small-health-qty) 1))
      < buy
    - [(and (<= 10 (item-count 'parts)) (< 0 (var 'medium-health-qty))) //Buy a medium health pack for 10 scrap parts// | I can't afford 10 scrap parts for a medium health pack.|] (stock: (var 'medium-health-qty))
      ! eval (retrieve 'parts 10)
      ! eval (store 'medium-health-pack 1)
      ! eval (setf (var 'medium-health-qty) (- (var 'medium-health-qty) 1))
      < buy
    - [(and (<= 20 (item-count 'parts)) (< 0 (var 'large-health-qty))) //Buy a large health pack for 20 scrap parts// | I can't afford 20 scrap parts for a large health pack.|] (stock: (var 'large-health-qty))
      ! eval (retrieve 'parts 20)
      ! eval (store 'large-health-pack 1)
      ! eval (setf (var 'large-health-qty) (- (var 'large-health-qty) 1))
      < buy
|#

#| TODO:
later talks with trader:
- ask specifically about each faction member
- get into his own history more
- why don't you join up? - reveal he doesn't visit the enemy faction
|#