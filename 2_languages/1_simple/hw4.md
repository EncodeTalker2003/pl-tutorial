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

For the exceptions in dynamic typed semantics, first we need to add new grammar rules for the functions that throw exceptions.

```k
  syntax Type ::= ...
			    | Types "->" Type "throws" Types
  syntax Stmt ::= ...
				| Type Id "(" Params ")" "throws" Types Block
```

Same to the `Type`, we modify the definition of the `lambda` closure to inlucde types coulbd be thrown.

```k
  syntax Val ::= ...
               | lambda(Type,Types,Params,Stmt)
```

For the configuration, we add a new `throwTypes` cell in the `control` cell in the configuration. This new cell indicates the types that current function could throw. Also, we modify the ways the `xstack` works so that it would only store the `catch` informations in current function.
```k
  configuration <T color="red">
                  <threads color="orange">
                    <thread multiplicity="*" color="yellow" type="Map">
                      <id color="pink"> 0 </id>
                      <k color="green"> ($PGM:Stmt ~> execute) </k>
                      <control color="cyan">
                        <fstack color="blue"> .List </fstack>
                        <xstack color="purple"> .List </xstack>
						<throwTypes color="DarkOrange"> .Types </throwTypes> // new
                        <returnType color="LimeGreen"> void </returnType>
                       </control>
                      <env color="violet"> .Map </env>
                      <holds color="black"> .Map </holds>
                    </thread>
                  </threads>
                  <genv color="pink"> .Map </genv>
                  <store color="white"> .Map </store>
                  <busy color="cyan">.Set</busy>
                  <terminated color="red"> .Set </terminated>
                  <input color="magenta" stream="stdin"> .List </input>
                  <output color="brown" stream="stdout"> .List </output>
                  <nextLoc color="gray"> 0 </nextLoc>
                </T>
```

When declaring a function, we need also to record the thrown types in the lambda closure.

```k
  rule <k> T:Type F:Id(Ps:Params) S => .K ...</k>
       <env> Env => Env[F <- L] </env>
       <store>... .Map => L |-> lambda(T, .Types, Ps, S) ...</store>
       <nextLoc> L => L +Int 1 </nextLoc>

  rule <k> T:Type F:Id(Ps:Params) throws TS S => .K ...</k>
       <env> Env => Env[F <- L] </env>
       <store>... .Map => L |-> lambda(T, TS, Ps, S) ...</store>
       <nextLoc> L => L +Int 1 </nextLoc>
```

When applying a function, we need to modify the ways previous `control` cell works. The new thing is that a function could throw exceptions and let its caller to catch it as long as this thrown type is declared in the function signature and the callee itself could not handle it.

```k
  syntax KItem ::= (Type,Map,K,List,Types,ControlCellFragment)  

  rule <k> lambda(T,TS,Ps,S)(Vs:Vals) ~> K => mkDecls(Ps,Vs) S return; </k>
       <control>
         <fstack> .List => ListItem((T',Env,K,XST,TS',C)) ...</fstack>
		 <xstack> XST => .List </xstack>
		 <throwTypes> TS' => TS </throwTypes>
         <returnType> T' => T </returnType>
		 C
       </control>
       <env> Env => GEnv </env>
       <genv> GEnv </genv>

  rule <k> return V:Val; ~> _ => V ~> K </k>
       <control>
         <fstack> ListItem((T',Env,K,XST,TS,C)) => .List ...</fstack>
         <returnType> T => T' </returnType>
		 <xstack> _ => XST </xstack>
		 <throwTypes> _ => TS </throwTypes>
		 (_ => C)
       </control>
       <env> _ => Env </env>
    requires typeOf(V) ==K T   // check the type of the returned value

  rule <k> throw V:Val; ~> _ </k>
       <control>
         <fstack> ListItem((T',Env,_,XST,TS',C)) => .List ...</fstack>
         <xstack> .List => XST </xstack>
		 <throwTypes> TS => TS' </throwTypes>
         <returnType> _ => T' </returnType>
		 (_ => C)
       </control>
       <env> _ => Env </env>
    requires findExist(typeOf(V), TS) 

  syntax Bool ::= findExist(Type,Types) [function]
  rule findExist(T:Type, T:Type, _:Types) => true
  rule findExist(T1:Type, T2:Type, Ts:Types) => findExist(T1, Ts) requires T1 =/=K T2
  rule findExist(T1:Type, T2:Type) => T1 =/=K T2
  rule findExist(_:Type, .Types) => false  
```

Finally, when throwing an exception that the top-level `catch` cannot handle, we simply discard this `catch`.
```k
  rule <k> throw V:Val; ~> _ </k>
       <control> 
	     <xstack> ListItem((T:Type _:Id, _, _, _:Map, _)) => .List ...</xstack>
		 _
	   </control>
	requires typeOf(V) =/=K T
```

Current approach could deal with some simple cases of exceptions:
```k
int foo(int x) throws int {
  throw 1;
}

void main() {
  try {
	throw foo;
  } catch(int -> int throws int) {
	print("OK\n");
  }
}
```

However, since now we store the thrown types as `List`. It might cause some problems when we have multiple types that could be thrown in comparasion. Like:
```k
int foo(int x) throws int, string {
  throw 1;
}

void main() {
  try {
	throw foo;
  } catch(int -> int throws string, int) {
	print("OK\n");
  }
}
```
This might fail due to the order of types in the `throws` clause.

### 3

For the exceptions in dynamic typed semantics, we omit the same grammar change here. We also add a `throwTypes` cell in the configuration. Now this cell indicates that their exists a `catch` hander for the `throw` outside, no matter it would catch other exceptions or not.

```k
  configuration <T color="yellow">
                  <tasks color="orange">
                    <task multiplicity="*" color="yellow" type="Set">
                      <k color="green"> $PGM:Stmt </k>
                      <tenv multiplicity="?" color="cyan"> .Map </tenv>
                      <returnType multiplicity="?" color="black"> void </returnType>
					  <throwTypes multiplicity="?" color="purple"> .Set </throwTypes> // new
                    </task>
                  </tasks>
                  <gtenv color="blue"> .Map </gtenv>
                </T>
```

Declaring a function that could throw exceptions is similar to a non-thrown one.
```k
  rule <task> <k> T:Type F:Id(Ps:Params) throws Ts:Types S => getTypes(Ps)->T throws Ts F; ...</k> </task>
       (.Bag => <task>
               <k> mkDecls(Ps) S </k> <tenv> .Map </tenv> <returnType> T </returnType> <throwTypes> convertList2Set(Ts) </throwTypes>
             </task>)

  syntax Set ::= convertList2Set(Types) [function]
  rule convertList2Set(T:Type, Ts:Types) => SetItem(T) convertList2Set(Ts)
  rule convertList2Set(.Types) => .Set
```

When applying a function, we first make sure that their is a handler for each type of excepetions that the function could throw, and then we do the application things.
```k
  rule <k> (_ -> _ throws ((TT1, TTs:Types) => TTs))(_)  ... </k>
       <throwTypes>... SetItem(TT1) ...</throwTypes>

  rule (Ts:Types -> T throws .Types)(Ts) => T requires Ts =/=K .Types
  rule (void -> T throws .Types)(.Types) => T
```

For `catch` statement, we add a new type to the `throwTypes` cell and work with the two blocks seperately. For `throw` statement, we check whether there is a handler for the thrown type. 
```k
  rule <task> 
         <k> try S1 catch (T:Type X:Id) {S} => {T X; S} ... </k>
         <throwTypes> TTs </throwTypes>
		 R
	   </task>
	   (.Bag => <task>
	              <k> S1 </k> 
				  <throwTypes> SetItem(T) TTs </throwTypes>
				  R
	           </task>)

  rule <task> 
         <k> try S1 catch (T:Type X:Id) { } => {T X;} ... </k>
         <throwTypes> TTs </throwTypes>
		 R
	   </task>
	   (.Bag => <task>
	              <k> S1 </k> 
				  <throwTypes> SetItem(T) TTs </throwTypes>
				  R
	           </task>)

  rule <k> throw T:Type; => stmt ...</k>
       <throwTypes>... SetItem(T) ...</throwTypes>
```


Current approach could deal with some simple cases of exceptions:
```k
int foo(int x) throws int {
  throw 1;
}

void main() {
  try {
	throw foo;
  } catch(int -> int throws int) {
	print("OK\n");
  }
}
```

However, since we lack information about the running state, we may reject some valid programs like:
```k
int foo(int x) throws int, string {
  throw 1;
}

void main() {
  try {
	foo();
  } catch(int) {
	print("OK\n");
  }
}
```

### 4

For rejecting duplication definitions in static typed SIMPLE. We add a new `declared` cell to store tha variables that has a definition in current scope.
```k
  configuration <T color="yellow">
                  <tasks color="orange">
                    <task multiplicity="*" color="yellow" type="Set">
                      <k color="green"> $PGM:Stmt </k>
                      <tenv multiplicity="?" color="cyan"> .Map </tenv>
                      <returnType multiplicity="?" color="black"> void </returnType>
					  <declared multiplicity="?" color="purple"> .Set </declared> // new
                    </task>
                  </tasks>
                  <gtenv color="blue"> .Map </gtenv>
                </T>
```

When defining a variable, we just add it to the `declared` cell. If it already exists, we would get stuck.
```k
  rule <k> T:Type X:Id; => stmt ...</k> <tenv> Rho => Rho[X <- T] </tenv> <declared> D => D SetItem(X) </declared>
    requires notBool X in D
```

Sometimes (like a `catch` statement), we do not need to record the arguments, so we do a flush of the `declared` cell.
```k
  syntax Stmt ::= "cleanDeclared" ";"  
  rule try block catch(int X:Id) {S} => {int X; cleanDeclared; S}
  rule try block catch(int X:Id) {} => {int X;}
  rule throw int; => stmt
  rule <k> cleanDeclared; => stmt ...</k> <declared> _ => .Set </declared>
```

Current approach could easily reject some simple programs:
```k
void main() {
  int x=0;
  int x=1;
}
```

But when the control flow is complex, like:
```k
void main() {
  if (1 == 0) {
	int x=0;
	int x=1;
  }
}
```
It might fail to reject it since we do not track the control flow precisely enough.