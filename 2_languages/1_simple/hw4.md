### 1

We add a new loop stack `lstack` in the `control` cell to deal with loop control. It would store the loop information.

```k
  configuration <T color="red">
                  <threads color="orange">
                    <thread multiplicity="*" type="Map" color="yellow">
                      <id color="pink"> -1 </id>
                      <k color="green"> $PGM:Stmt ~> execute </k>
                      <control color="cyan">
                        <fstack color="blue"> .List </fstack>
                        <xstack color="purple"> .List </xstack>
						<lstack color="orange"> .List </lstack> // new
                      </control>
                      <env color="violet"> .Map </env>
                      <holds color="black"> .Map </holds>
                    </thread>
                  </threads>
                  <genv color="pink"> .Map </genv>
                  <store color="white"> .Map </store>
                  <busy color="cyan"> .Set </busy>
                  <terminated color="red"> .Set </terminated>
                  <input color="magenta" stream="stdin"> .List </input>
                  <output color="brown" stream="stdout"> .List </output>
                  <nextLoc color="gray"> 0 </nextLoc>
                </T>
```

The element of the element for the `lstack` cell is as follows: 
- The first two elements are the `Env`  we need to reset when the control of the loop is transferred. When a round of execution in a loop ends or a `continue` statement is encountered, we need to reset the `Env` to the first element. When we need to exit current loop or a `break` statement is encountered, we need to reset the `Env` to the second element. The reason we need two `Env` is that the we might need to define some new variables in the loop but before entering the loop body (like iterator variable in `for` loop). Later, we would use the `break` and `continue` statements to control the loop execution, even though there are no such statements in the original program.
- The third element is the `K` cell fragment that stores the statements after the loop.
- The fourth element is the `ControlCellFragment` that stores the `fstack` and `xstack` when entering the loop.
- The fifth element is the `Stmt` of the loop body.

```k
  syntax KItem ::= (Map,Map,K,ControlCellFragment,Stmt)
```

For a `while` loop, we could translate it to repeat an `if-else` statement.

```k
  rule <k> (while (E) S ~> K) => (if (E) S else {break;} continue;) </k>
	   <control>
	     <lstack> .List => ListItem((Env, Env, K, C, if (E) S else {break;} continue;)) ...</lstack>
         C
	   </control>
	   <env> Env </env>
```

For a `for` loop, we need first to do some declaratuion and initialization work in the `Start` part, then we could dive into the loop. We use a `pushEnv` instruction to temporarily save the current `Env` before the initialization.

```k
  syntax KItem ::= "pushEnv" Map

  rule <k> ((for (Start Cond; Step) S) => (Start ~> pushEnv Env ~> for (Start Cond; Step) S)) ~> _ </k>
	   <env> Env </env>

  rule <k> (pushEnv Env2 ~> for (_ Cond; Step) S ~> K) => (if (Cond) S else { break; } continue;) </k>
	   <control>
         <lstack> .List => ListItem((Env, Env2, K, C, Step; if (Cond) S else { break; } continue;)) ...</lstack>
		 C
	   </control>
	   <env> Env </env>
```

For the `break` and `continue` statements, we could simpli choose the proper environment and restore everything.

```k
  rule <k> (continue; ~> _) => LoopBody </k>
	   <control>
	     <lstack> ListItem((Env, _, _, C, LoopBody))  ...</lstack>
         (_ => C)
	   </control>
	   <env> _ => Env </env>

  rule <k> (break; ~> _ ) => K </k>
	   <control>
	   	 <lstack> ListItem((_, Env2, K, C, _)) => .List ...</lstack>
         (_ => C)
	   </control>
	   <env> _ => Env2 </env>
```

This approach works well when we have only one function:

```
function main() {
  while(true) {
    break;
  }
  print("OK\n");
}
```

However, when we have a function call inside a loop and that function wrongly uses `break` or `continue`, it would cause problems. For example:

```
function foo() {
  break;
}

function main() {
  while(true) {
	foo();
  }	
  print("You should not reach here\n");
}
```

Instead of getting stuck in the infinite loop, the program would terminate abnormally because the `break` statement in `foo` would try to pop the `lstack` and exit the loop in `main`.

### 2

For the exceptions in dynamic typed semantics 