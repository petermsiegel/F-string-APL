:Namespace ⍙Fapl
  ⎕IO  ⎕ML←0 1                 ⍝ Namespace scope. User code is executed in caller space (⊃⎕RSI)  
  DEBUG← 0                     ⍝ DEBUG←1 turns off top-level error trapping...
  helpHtmlFi← '∆F_Help.html'   ⍝ Called from 'help' option. Globally set here

⍝ ============================   ∆F User Function   ============================= ⍝
⍝ ∆F:  
⍝    result← {opts←⍬} ∇ f-string [args]
⍝ This function must be independent of ⎕IO, ⎕ML, etc., since it will be promoted out of ⍙Fapl.
⍝ ¨⎕THIS¨ will be hardwired as ∆F is promoted out of ⍙Fapl.
⍝ This has to be a tradfn, since it may return a dfn (with 1=⊃opts)
⍝
⍝ Actions...
⍝   If opts is not a simple vector with all integer options,
⍝           calls ⎕THIS.Help to display HELP or signal an error.
⍝   With opts an integer vector, examine (⊃opts). 
⍝    If  1: Returns executable dfn CODE generated from the f-string (if valid).                   
⍝    If ¯1: Undocumented option-- returns dfn code in string form. 
⍝           Useful for benchmarking compile-only step using dfns.cmpx.
⍝           (⍎¯1... ∆F ...)args <===> (1... ∆F ...)args 
⍝    If 0 or anything else:
⍝           Handle options (valid and invalid) in ⎕THIS.FmtScan
⍝           Returns matrix RESULT of evaluating the f-string.
⍝ 
⍝   On execution (default mode), "hides" local vars, ¨opts¨ and ¨args¨, from embedded ⎕NL, etc.
⍝   This avoids them showing on ⎕NL or related calls.
  ∇ result← {opts} ∆F args                             ⍝ For doc, see ∆F in ∆Fapl.dyalog.
    :Trap 0/⍨ ~⎕THIS.DEBUG                
      :If 900⌶0 
          opts← ⍬
      :ElseIf ~11 3∊⍨ 80|⎕DR opts                      ⍝ non-numeric opts => (Help | error).  
          result← ⎕THIS.Help opts 
          :Return          
      :EndIf 
    ⍝ Modes: 0 => array mode, 1 => dfn, ¯1 => dfn as string, else => help or error
      args← ,⊆args
      :Select ⊃opts← 4↑ opts   
        :Case  0       ⍝ ⍵: all args (f-string etc.), used by ⍎. FmtScan sees just the f-string.
          result← opts ((⊃⎕RSI){ ⍺⍺⍎ ⍺ ⎕THIS.FmtScan ,⊃⍵⊣ ⎕EX 'opts' 'args'}) args    
        :Case  1       ⍝ ,⊃args: just the f-string      ⍝ 1:  returns dfn    
          ⎕SHADOW '∆F_Dfn'                             ⍝ Give returned dfn a mnemonic name...                                          
          result← ∆F_dfn← (⊃⎕RSI)⍎ opts ⎕THIS.FmtScan ,⊃args
        :Case ¯1       ⍝ ,⊃args: ust the f-string      ⍝ ¯1:  returns dfn string (undocumented)                                
          result← opts ⎕THIS.FmtScan ,⊃args            
        :Else          ⍝ opts matches 'help'; else error!         
          result← ⎕THIS.Help opts  
      :EndSelect   
    :Else 
        ⎕SIGNAL ⊂⎕DMX.('EM' 'EN' 'Message' ,⍥⊂¨('∆F ',EM) EN Message)
    :EndTrap 
   ⍝ (C) 2025 Sam the Cat Foundation
  ∇

⍝ ============================   FmtScan ( top-level routine )   ============================= ⍝
⍝ FmtScan: 
⍝    result← [4↑ options] ∇ f_string
⍝ "Main" function called by ∆F above. See the Executive section below.
⍝ Calls Major Field Recursive Scanners: 
⍝    TF: text, CF_SF: code fields and space fields, CFStr: (code field) quoted strings
  FmtScan← {  
    ⍝ TF: Text Field Scan 
    ⍝     (accum|'') ∇ str
    ⍝ Calls: TF (recursively) and CF_SF (which calls TF in return).
    ⍝ Returns: null. Appends APL code strings to fldsG
    TF← {  
        p← TFBrk ⍵                                     ⍝ esc, lb, or cr only. 
      p= ≢⍵: TFDone ⍺, ⍵                               ⍝ No special chars in ⍵. Process & return.
        pfx c w← (p↑⍵) (p⌷⍵) (⍵↓⍨ p+1) 
      c= esc: (⍺, pfx, nlG TFEsc w) ∇ 1↓ w             ⍝ char is esc. Process & continue.
    ⍝ c= cr:  (⍺, pfx, nlG) ∇ w                        ⍝ actual cr => nlG, mirroring esc+⋄ => nlG. 
        CF_SF w⊣ TFDone ⍺, pfx                         ⍝ char is lb. End TF; go to CF_SF.  
    } ⍝ End Text Field Scan 

  ⍝ TFDone: If a text field is not 0-length, place in quotes and add it to fldsG.
  ⍝ Ensure adjacent fields are sep by ≥1 blank.
    TFDone← {0≠ ≢⍵: 0⊣ fldsG,← ⊂sp_sq, sq,⍨ ⍵/⍨ 1+ sq= ⍵ ⋄ ⍬}    

  ⍝ CF_SF: Code and Space Field Scan (monadic only).
  ⍝     res← ∇ str, where str starts just past the leading '{' of the CF.  
  ⍝ Called by TF. 
  ⍝ If it sees /^\s*\}/, it emits SF code (if no spaces) and recurses "back" to TF.
  ⍝ Otherwise, it processes a code field. 
  ⍝ Returns: null. Appends APL code strings to fldsG. Sets/modifies nBracG, cfLenG.
    CF_SF← {                                              
        cfV← w← ⍵                                      ⍝ cfV: Save the CF verbatim. Used in ⍙Scan.
      rb= ⊃w: '' TF 1↓ w                               ⍝ Null SF? No code gen'd. => Done. [FAST]
        w↓⍨← nSp← +/∧\' '= w                           ⍝ Count/skip over (≥0) leading spaces...
      rb= ⊃w: '' TF 1↓ w⊣ fldsG,← ⊂SFCode nSp          ⍝ SF? => Done.
        nBracG cfLenG⊢← 1 nSp                          ⍝ CF => Scan Code Field
        ⍙Scan← {                                       ⍝ Reads cfV above. Modifies cfLenG, nBracG.  
            cfLenG+← 1+ p← CFBrk ⍵
          p= ≢⍵:  ⎕SIGNAL brÊ                          ⍝ Missing "}" => Error. 
            pfx c w← (⍺, p↑⍵) (p⌷⍵) (⍵↓⍨ p+1)          ⍝ Some cases below (marked [１]) are ordered! 
          c= sp:     (pfx, sp) ∇ w↓⍨ cfLenG+← p← +/∧\' '=w ⍝ Handle runs of blanks
         (c= rb)∧ nBracG≤ 1: (TrimR pfx) w             ⍝ [１] Closing "}" => Return... Scan complete! 
          c∊ lb_rb:  (pfx, c) ∇ w⊣ nBracG+← -/c= lb_rb ⍝ [１] Inc/dec nBracG as appropriate
          c∊ qtsL:   (pfx, a)  ∇ w⊣  cfLenG+← c⊣ a w c← CFStr c w  ⍝ Opening quote => CFStr  
          c= dol:    (pfx, scF) ∇ w                    ⍝ $ => ⎕FMT (scF shortcut)
          c= esc:    (pfx, a)  ∇ w⊣ a w← CFEsc w       ⍝ `⍵, `⋄, `A, `B, etc.
          c= omUs:   (pfx, a)  ∇ w⊣ a w← CFOm w        ⍝ ⍹, alias to `⍵ (see CFEsc).
         ~c∊ sdcfCh: ⎕SIGNAL cfLogicÊ 
          p← +/∧\' '=w  
        ⍝ SDCF Detection...       
        ⍝ c is one of '→', '↓', or '%'. 
        ⍝ See if [A] we have a shortcut/APL fn or [B] an indicator of a self-doc code field (SDCF).
        ⍝ [A] We have a Shortcut or APL Fn <<<<<       
        ⍝ Shortcut "above" '%' or APL fns '→'¹ or '↓'. 
        ⍝ [¹] Only a bare → is valid in a dfn stmt, so good luck. 
          (rb≠ ⊃p↓w)∨ nBracG> 1: (pfx, c scA⊃⍨ c= pct) ∇ w  ⍝ Continue CF Scan
        ⍝ [B]: We have a Self-Documenting Code Field (SDCF)  
        ⍝ SDCF: We have matched: /[→↓%]\s*\}/  
        ⍝ '→' places the code str to the left of the result (scM=merge) after evaluating the code str; 
        ⍝ '↓' or its alias '%' puts it above (scA) the result.
            codeStr← AplQt cfV↑⍨ cfLenG+ p              
            (codeStr, (scA scM⊃⍨ c='→'), pfx)(w↓⍨ p+1) ⍝ => Return: Scan complete!  
        }
        a w← '' ⍙Scan w
        '' TF w⊣ fldsG,← ⊂'(', lb, a, rb, '⍵)'         ⍝ Process field & then head to TF
    } ⍝ End CF_SF (Code/Space Field Scan)
  
  ⍝ SFCode: Generate a SF code string; ⍵ is a pos. integer. (Used in CF_SF above)
    SFCode← ('(',⊢ ⊢,∘'⍴'''')')⍕  

  ⍝ CFStr: CF Quoted String Scan
  ⍝        val←  ∇ qtL fstr 
  ⍝ ∘ Right now, qtL must be ', ", or «, and qtR must be ', ", or ». 
  ⍝ ∘ For quotes with different starting and ending chars, e.g. « » (⎕UCS 171 187).
  ⍝   If « is the left qt, then the right qt » can be doubled in the APL style, 
  ⍝   and a non-doubled » terminates as expected.
  ⍝ Note: See note at <c= cr> below. See also function TF.
  ⍝ Returns val← (the string at the start of ⍵) (the rest of ⍵) ⍝  
    CFStr← { 
        qtL w← ⍵ ⋄ qtR← (qtsL⍳ qtL)⌷ qtsR              ⍝ See above.
        CFSBrk← ⌊/⍳∘(esc qtR) ⍝  cr)                   ⍝ See note at <c= cr> below.
        lenW← ¯1+ ≢w                                   ⍝ lenW: length of w outside quoted str.
        ⍙Scan← {   ⍝ Recursive CF Quoted-String Scan. lenW converges on true length.
          0= ≢⍵: ⍺ 
            p← CFSBrk ⍵  
          p= ≢⍵: ⎕SIGNAL qtÊ ⋄ c← p⌷⍵
          c= esc: (⍺, (p↑ ⍵), nlG QSEsc ⊃⍵↓⍨ p+1) ∇ ⍵↓⍨ lenW-← p+2 
        ⍝ OPTIONAL: actual cr  => nlG, mirroring esc+⋄ => nlG. 
        ⍝ c= cr:  (⍺, nlG) ∇ ⍵↓~ lenW-← 1              
        ⍝ Now c= qtR:  Now see if c2, the next char, is a second qtR, 
        ⍝ i.e. an internal, literal qtR. Only qtR can be doubled (e.g. », not «)
            c2← ⊃⍵↓⍨ p+1
          c2= qtR:  (⍺, ⍵↑⍨ p+1) ∇ ⍵↓⍨ lenW-← p+2      ⍝ Use APL rules for doubled ', ", or »
            ⍺, ⍵↑⍨ lenW-← p                            ⍝ Done... Return
        }
        qS← AplQt '' ⍙Scan w                           ⍝ Update lenW via ⍙Scan, then update w. 
        qS (w↑⍨ -lenW) (lenW-⍨ ≢ w)                    ⍝ w is returned sans CF quoted string 
    } ⍝ End CF Quoted-String Scan
    
  ⍝ CFEsc: Handle escapes  in Code Fields OUTSIDE of CF-Quotes.
  ⍝    res← ∇ fstr
  ⍝ Returns:  code w                                    ⍝ ** Side Effects: Sets cfLenG, omIxG **
    CFEsc← {                                    
      0= ≢⍵: esc 
        c w← (0⌷⍵) (1↓⍵) ⋄ cfLenG+← 1   
      c∊ om_omUs: CFOm w                               ⍝ Permissively allow `⍹ as equiv to  `⍵ OR ⍹   
      nSC> p← MapSC c: (p⊃ userSCs) w                  ⍝ userSCs: user shortcuts `[ABFTDW]. 
      c∊⍥⎕C ⎕A: ⎕SIGNAL ShortcutÊ c                    ⍝ Unknown shortcut!
        ⎕SIGNAL EscÊ c                                 ⍝ Esc-c has no mng in CF for non-Alph char c.
    } ⍝ End CFEsc 

  ⍝ CFOm:   omCode w← ∇ ⍵ 
  ⍝ ⍵: /\d*/, i.e. optional digits starting right AFTER `⍵ or ⍹ symbols, for 
  ⍝ Returns omCode w:
  ⍝    omCode: the emitted code for selecting from the ∆F right arg (⍵);
  ⍝    w:      ⍵, just past the matched omega expression digits.
  ⍝ Errors Signaled: None. 
  ⍝   IntOpt matches valid digits adjacent to `⍵ or ⍹, if any; otherwise indicates a "bare" `⍵ or ⍹
  ⍝ Side Effects: 
  ⍝   Modifies cfLenG, omIxG to reflect the # of digits matched and their value.  
    CFOm← { oLen oVal w← IntOpt ⍵
      ×oLen: ('(⍵⊃⍨',')',⍨ '⎕IO+', ⍕omIxG⊢← oVal) w⊣ cfLenG+← oLen 
             ('(⍵⊃⍨',')',⍨ '⎕IO+', ⍕omIxG       ) w⊣ omIxG+← 1
    }
⍝ ===========================================================================
⍝ FmtScan Executive begins here
⍝ ===========================================================================  
⍝   Valid ⍺: ⍺[0]∊ ¯1 0 1, ∧/ ⍺[1 2 3]∊ 0 1
    0∊ 0 1∊⍨ (|⊃⍺), 1↓⍺: ⎕SIGNAL optÊ                  ⍝ Invalid options (⍺)!
    (dfn dbg box inline) fStr← ⍺ ⍵ 
    DM← (⎕∘←)⍣(dbg∧dfn≥0)                              ⍝ DM: Debug Msg
    nlG← dbg⊃ cr crVis                                 ⍝ A newline escape (`⋄) maps onto crVis if debug mode.
  ⍝ User Shortcuts: A, B, C, F, T~D, Q, W.  
  ⍝ Non-user Internal Shortcut Code and dfns: scÐ, Ð;  scM, M.
  ⍝ See ⍙LoadShortcuts for shortcut details and associated variables scA, scB, etc.     
    scA scB scC scÐ scF scM scT scQ scW← inline⊃¨ scList ⍝ code fragments.
  ⍝  userSCs must be ordered acc. to sc (sc← 'ABCFTDQW'). See function MapSC and its use.  
  ⍝           `A  `B  `C      `F  `T  `D  `Q  `W 
    userSCs← scA scB scC     scF scT scT scQ scW            
 
  ⍝ Pseudo-globals  camelCaseG 
  ⍝    fldsG-   global field list
  ⍝    omIxG-   omega index counter: current index for omega shortcuts (`⍵, ⍹)  
  ⍝    nBracG-  running count of braces '{' lb, '}' rb
  ⍝    cfLenG-  code field running length (used when a self-doc code field (q.v.) occurs)  
    fldsG← ⍬                                           ⍝ zilde
    omIxG← nBracG← cfLenG← 0                           ⍝ zero
  
  ⍝ Start the scan                                     ⍝ We start with a (possibly null) text field, 
    _← '' TF ⍵                                         ⍝ recursively calling CF_SF and (from CF_SF) SF & TF itself, &
                                                       ⍝ ... setting fields ¨fldsG¨ as we go.
  0= ≢fldsG: DM '(1 0⍴⍬)', '⍨'/⍨ dfn=0                 ⍝ If there are no flds, return 1 by 0 matrix
    fldsG← OrderFlds fldsG                             ⍝ We will evaluate fields L-to-R
    code← '⍵',⍨ lb, rb,⍨ fldsG,⍨ box⊃ scM scÐ
  0=dfn: DM code                                        ⍝ Not a dfn. Emit code ready to execute
    quoted← ',⍨ ⊂', AplQt fStr                         ⍝ Dfn: add quoted fmt string (`⍵0)
    DM lb, code, quoted, rb                            ⍝ Emit dfn str ready to cvt to dfn in caller
  } ⍝ FmtScan 

⍝ ===========================================================================  
⍝                            ***   CONSTANTS ***
⍝ ===========================================================================  

⍝ Simple char constants
⍝ Note: we handle two kinds of quotes: 
⍝     std same-char quotes, 'this' and "this", with std APL-style doubling.
⍝     left- and right-quotes, «like this», where only the right-quote doubling is needed
⍝     (i.e. any number of literals « can be in a «» string.)
⍝ The use of double angle quotation marks is an amusement. No good use AFAIK.
  om← '⍵'                                          ⍝ ⍵ not in cfBrklist, since not special. (See `⍵).
  cr crVis← ⎕UCS 13 9229               
⍝ Seq. `⋄ OR `◇ map onto ⎕UCS 13.
⍝ dia2[0]: Dyalog stmt separator
⍝ dia2[1]: Alternative character that is easier to read in some web browsers. 
  dia2← ⎕UCS 8900 9671
⍝ lDAQ, rDAQ: LEFT- and RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK, aka guillemets  
  lDAQ rDAQ← '«»'                                      ⍝ ⎕UCS 171 187 
⍝ Order brklist chars roughly by frequency, high to low.       
  cfBrkList← lDAQ,⍨ sp sq dq esc lb rb dol omUs ra da pct← ' ''"`{}$⍹→↓%' 
  tfBrkList← esc lb   ⍝ cr                 
  lb_rb← lb rb ⋄ om_omUs← om omUs ⋄ sp_sq← sp sq ⋄   esc_lb_rb← esc lb rb  
  qtsL qtsR← lDAQ rDAQ,⍨¨ ⊂dq sq                       ⍝ Expected freq hi to lo: dq sq l/rDAQ
  sdcfCh← ra da pct                                    ⍝ self-doc code field chars

⍝ Error constants / fns  
    Ê← { ⍺←11 ⋄ ⊂'EN' ⍺,⍥⊂ 'Message' ⍵ }
  brÊ←         Ê 'Unpaired brace "{"'
  qtÊ←         Ê 'Unpaired quote (''"'' or "''") in code field' 
  cfLogicÊ←    Ê 'A logic error has occurred processing a code field'
  optÊ←        Ê 'Invalid option(s) in left argument. For help: ∆F⍨''help'''
  ShortcutÊ←   Ê {'Sequence "`',⍵,'" does not represent a valid shortcut.'}
  EscÊ←        Ê {'Sequence "`',⍵,'" is not valid in code outside strings. Did you mean "',⍵,'"?'}
  helpFiÊ←  22 Ê 'Help file "',helpHtmlFi,'" not found in current directory'

⍝ Other fns/ops for FmtScan above (no side effects). 
⍝ =========================================================================
⍝ These have NO side effects, so need not be in the scope of FmtScan. 
⍝ =========================================================================
⍝ See also CFSBrk
  TFBrk← ⌊/⍳∘tfBrkList
  CFBrk← ⌊/⍳∘cfBrkList

  TrimR←  ⊢↓⍨-∘(⊥⍨sp=⊢)                                ⍝ { ⍵↓⍨ -+/∧\⌽⍵= sp}
⍝ IntOpt: Does ⍵ start with a valid sequence of digits (a non-neg integer)? 
⍝ Returns 2 integers and a string: 
⍝   [0] len of sequence of digits (pos integer) or 0, 
⍝   [1] the integer value found or 0, 
⍝   [2] ⍵ after skipping the prefix of digits, if any.
⍝ If [0] is 0, then there was no prefix of digits. If there was, then it will be >0.
  IntOpt← { wid← +/∧\ ⍵∊⎕D ⋄ wid (⊃⊃⌽⎕VFI wid↑ ⍵) (wid↓ ⍵) }  ⍝ Idiom +/∧\

⍝ AplQt:  Created an APL-style single-quoted string.
  AplQt←  sq∘(⊣,⊣,⍨⊢⊢⍤/⍨1+=)                           ⍝ { sq, sq,⍨ ⍵/⍨ 1+ sq= ⍵ }

⍝ Escape key Handlers: TFEsc QSEsc   (CFEsc, with side effects, is within FmtScan)
⍝ *** No side effects *** 
⍝ TFEsc: nl ∇ fstr, where 
⍝    nl: current newline char;  fstr: starts with the char after the escape
⍝ Returns: the escape sequence.                        ⍝ *** No side effects ***
  TFEsc← { 0= ≢⍵: esc ⋄ c← 0⌷⍵ ⋄ c∊ dia2: ⍺ ⋄ c∊ esc_lb_rb: c ⋄ esc, c } 
  ⍝ QSEsc: [nl] ∇ fstr, where 
  ⍝         nl is the current newline char, and fstr starts with the char AFTER the escape char.
  ⍝ Returns the escape sequence.                       ⍝ *** No side effects ***
  QSEsc← { c← ⍵ ⋄ c∊ dia2: ⍺ ⋄ c=esc: c ⋄ esc, c }     

⍝ OrderFlds
⍝ ∘ User flds are effectively executed L-to-R AND displayed in L-to-R order 
⍝   by ensuring there are at least two fields (one null, as needed), 
⍝   reversing their order now (at evaluation time), evaluating each field 
⍝   via APL ⍎ in turn R-to-L, then reversing again at execution time. 
  OrderFlds← '⌽',(∊∘⌽,∘'⍬') 

⍝ Help: Provides help info. Called only one of the following is called: 
⍝       'help' ∆F anything  OR  ∆F⍨'help'
⍝ (1 0⍴⍬)← ∇ ⍵
⍝ 1. If ⍵ is not 'help' (any case), an error is signaled.
⍝ 2. If helpHtml is not defined or if DEBUG=1, helpHtmlFi will be read and copied into helpHtml. 
⍝ 3. Displays helpHtml.
  Help← { 
    'help'≢ 4↑⎕C⍵: ⎕SIGNAL optÊ 
    _h← {  
      22:: ⎕SIGNAL helpFiÊ 
      DEBUG∨ ⍵: ⊢⎕THIS.helpHtml← ⊃⎕NGET helpHtmlFi 
        ⎕THIS.helpHtml  
    } 0= ⎕NC 'helpHtml' 
    _c← '∆F Help Information'
    _o← ('HTML'  _h) (900 1000,⍨ ⊂'Size') (10 10,⍨ ⊂'Posn') ('Coord' 'ScaledPixel')
    _← 'htmlObj' ⎕THIS.⎕WC 'HTMLRenderer',⍥⊆ _o          ⍝ Run HTMLRenderer
    1 0⍴⍬
  } 

⍝ ===============================   FIX-time Routines   ================================ 
⍝ ⍙Promote_∆F: rc← ∇ dest     
⍝ Used internally only at FIX-time:
⍝ ∘ Fix (⎕FX) ∆F into dest, obscuring its local names and hardwiring the location of ⎕THIS. 
  ∇ rc← ⍙Promote_∆F dest ; src; snk 
    src←    '⎕THIS'      'result'     'opts'     'args' 
    snk←   (⍕⎕THIS)  '__∆Frësült' '__∆Föpts' '__∆Färgs'
    rc← dest.⎕FX src ⎕R snk ⍠ 'UCP' 1⊣ ⎕NR '∆F'
  ∇

⍝ ⍙LoadShortcuts:   ∇     (niladic) 
⍝ At ⎕FIX time, load the run-time library names and code for user Shortcuts
⍝ and similar code (Ð, display, is used internally, so not a true user shortcut).
⍝ The library entries created in ∆Fapl are: 
⍝  ∘  for shortcuts:    A, B, C, F, Q, T, W     ⍝ T supports `T, `D
⍝  ∘  used internally:  M, Ð.
⍝ A (etc): a dfn
⍝ scA (etc): [0] local absolute name of dfn (with spaces), [1] its code              
⍝ Abbrev  Descript.       Valence     User Shortcuts   Notes
⍝ A       [⍺]above ⍵      ambi       `A, %             Center ⍺ above ⍵. ⍺←''.  Std is %
⍝ B       box ⍵           ambi       `B                Put ⍵ in a box.
⍝ C       commas          monadic    `C                Add commas to numbers every 3 digits R-to-L
⍝ Ð       display ⍵       dyadic                       Var Ð only used internally...
⍝ F       [⍺]format ⍵     ambi       `F, $             ⎕FMT.   Std is $
⍝ M       merge[⍺] ⍵      ambi                         Var M only used internally...
⍝ Q       quote ⍵         ambi       `Q                Put only text in quotes. ⍺←''''
⍝ T       ⍺ date-time ⍵   dyadic     `T, `D            Format ⍵, ⎕TS date-time(s), acc. to ⍺.
⍝ W       [⍺1 ⍺2]wrap ⍵   ambi       `W                Wrap ⍵ in decorators, ⍺1 ⍺2.  ⍺←''''. See doc.
⍝
⍝ For A, B, C, D, F, M, Q, T, W; all like A example shown here:
⍝     A← an executable dfn in this namespace (⎕THIS).
⍝     scA2← name codeString, where
⍝          name is (⍕⎕THIS),'.A'
⍝          codeString is the executable dfn in string form.
⍝ At runtime, we'll generate shortcut code "pointers" scA, scB etc. based on flag ¨inline¨.
  ∇ {ok}← ⍙LoadShortcuts 
    ; XR ;HT 
    XR← ⎕THIS.⍎⊃∘⌽                                   ⍝ XR: Execute the right-hand expression
    HT← '⎕THIS' ⎕R (⍕⎕THIS)                          ⍝ HT: "Hardwire" absolute ⎕THIS. 
    ⎕SHADOW '; sc; scA2; scB2; scC2; scÐ2; scF2; scM2; scT2; scQ2; scW2' ~';' 
    A← XR scA2← HT   ' ⎕THIS.A ' '{⍺←⍬⋄⎕ML←1⋄⊃⍪/(⌈2÷⍨w-m)⌽¨f↑⍤1⍨¨m←⌈/w←⊃∘⌽⍤⍴¨f←⎕FMT¨⍺⍵}' 
    B← XR scB2← HT   ' ⎕THIS.B ' '{⍺←0⋄⎕ML←1⋄⍺⎕SE.Dyalog.Utils.disp⊂⍣(1≥≡⍵),⍣(0=≡⍵)⊢⍵}' 
      ⎕SHADOW 'cCod' 
      cCod← {
            _←  '{'
            _,←    '1<⍴⍴⍵: ∇⍤1⊢ ⍵⋄'
            _,←    '⎕FR ⎕PP← 1287 34⋄'
            _,←    't←''[.Ee].*$'' ''(?<=\d)(?=(\d{3})+([-¯.Ee]|$))''⎕R''&'' '',&''⍕¨⍵⋄'
            _,←    '1=≢⍵:⊃t⋄'
            _,←    't'
            _,  '}'
      }⍬
    C← XR scC2← HT   ' ⎕THIS.C ' cCod 
    Ð← XR scÐ2← HT   ' ⎕THIS.Ð ' ' 0∘⎕SE.Dyalog.Utils.disp¯1∘↓'                           
    F← XR scF2←      ' ⎕FMT '    ' ⎕FMT '                                                
    M← XR scM2← HT   ' ⎕THIS.M ' '{⍺←⊢⋄⎕ML←1⋄⊃,/((⌈/≢¨)↑¨⊢)⎕FMT¨⍺⍵}'                     
      ⎕SHADOW 'qCod'
      qCod← {
          _←  '{'
          _,← ' ⍺←⎕UCS 39⋄'                               ⍝ ⍺ defaults to a single quote.
          _,← ' 1<|≡⍵:⍺∘∇¨⍵⋄'                             ⍝ It's not simple ==> handle.
          _,← ' (0=⍴⍴⍵)∧1=≡⍵:⍵⋄'                          ⍝ It's an ⎕OR ==> handle.
          _,← ' (0≠≡⍵)∧326=⎕DR⍵:⍺∘∇¨⍵⋄'                   ⍝ It's heterogeneous: 1 'x' 2 3.                                              
          _,← ' ⍺{0=80|⎕DR⍵:⍺,⍺,⍨⍵/⍨ 1+⍺=⍵⋄⍵}⍤1⊢⍵'        ⍝ If a vector/row is char, put in quotes.
          _,  '}'
      }⍬
    Q← XR scQ2← HT   ' ⎕THIS.Q ' qCod 
    T← XR scT2← HT   ' ⎕THIS.T ' '{⍺←''YYYY-MM-DD hh:mm:ss''⋄∊⍣(1=≡⍵)⊢⍺(1200⌶)⊢1⎕DT⊆⍵}'  
    W← XR scW2← HT ' ⎕THIS.W ' '{⍺←⎕UCS 39⋄ 1<|≡⍵: ⍺∘∇¨⍵⋄L R←2⍴⍺⋄{L,R,⍨⍕⍵}⍤1⊢⍵}'
  ⍝ Load externals: scList, nSC, MapSC 
    scList← scA2 scB2 scC2 scÐ2 scF2 scM2 scT2 scQ2 scW2  ⍝ All shortcuts, including internal ones.
    nSC← ≢  sc← 'ABCFTDQW'                                ⍝ sc: User-callable shortcuts  (`A, etc.)
    MapSC←  sc∘⍳ 
    ok← 1 
  ∇
  ∇ ok← ⍙LoadHelp; ⎕PW; e1; e2 
    ⎕PW←120
    :If 0=≢   { 22:: ⍬ ⋄ ⎕THIS.helpHtml← ⊃⎕NGET ⍵ } helpHtmlFi
         e1← 'WARNING: When loading ∆Fapl, the help file "',helpHtmlFi,'" was not found in current directory.'
         e2← 'WARNING: ∆F help will not be available without user intervention.'
         e1,(⎕UCS 13),e2
    :EndIf 
    ok← 1 
  ∇
⍝ Execute FIX-time routines
  ⍙Promote_∆F ##  
  ⍙LoadShortcuts
  ⍙LoadHelp
 
⍝ === END OF CODE ================================================================================
⍝ === END OF CODE ================================================================================
:EndNamespace 

⍝ (C) 2025 Sam the Cat Foundation
