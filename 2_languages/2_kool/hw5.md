### 1

First, we add a new `privateEnv` cell to keep track of all the private members in current object。 This is used on the declaration stage and would be stored in the `envStackFrame` later when dealing with `storeObj`.

```k
configuration <T color="red">
                  <threads color="orange">
                    <thread multiplicity="*" type="Set" color="yellow">
                      <k color="green"> $PGM:Stmt ~> execute </k>
                      <control color="cyan">
                        <fstack color="blue"> .List </fstack>
                        <xstack color="purple"> .List </xstack>
                        <crntObj color="Fuchsia">  // KOOL
                           <crntClass> Object </crntClass>
                           <envStack> .List </envStack>
                           <location multiplicity="?"> .K </location>
                        </crntObj>
                      </control>
                      <env color="violet"> .Map </env>
					  <privateEnv color="LightGray"> .Set </privateEnv> // new 
                      <holds color="black"> .Map </holds>
                      <id color="pink"> 0 </id>
                    </thread>
                  </threads>
                  <store color="white"> .Map </store>
                  <busy color="cyan">.Set </busy>
                  <terminated color="red"> .Set </terminated>
                  <input color="magenta" stream="stdin"> .List </input>
                  <output color="brown" stream="stdout"> .List </output>
                  <nextLoc color="gray"> 0 </nextLoc>
                  <classes color="Fuchsia">        // KOOL
                     <classData multiplicity="*" type="Map" color="Fuchsia">
                        // the Map has as its key the first child of the cell,
                        // in this case the className cell.
                        <className color="Fuchsia"> Main </className>
                        <baseClass color="Fuchsia"> Object </baseClass>
                        <declarations color="Fuchsia"> .K </declarations>
                     </classData>
                  </classes>
                </T>
```

For declaration of private variables and methods, everything keeps the same with normal variable andc method declaration, except that we also add its name to the `privateEnv` cell.

```k
rule private var E1::Exp, E2::Exp, Es::Exps; => private var E1; private var E2, Es;  [anywhere]
rule private var X::Id = E; => private var X; X = E;               [anywhere]
rule <k> private var X:Id; => .K ...</k>
	 <env> Env => Env[X <- L] </env>
	 <store>... .Map => L |-> undefined ...</store>
	 <nextLoc> L:Int => L +Int 1 </nextLoc>
	 <privateEnv>... .Set => SetItem(X) </privateEnv>

rule <k> private method F:Id(Xs:Ids) S => .K ...</k>
       <crntClass> Class:Id </crntClass>
       <location> OL:Int </location>
       <env> Env => Env[F <- L] </env>
	   <privateEnv>... .Set => SetItem(F) </privateEnv>
       <store>... .Map => L |-> methodClosure(Class,OL,Xs,S) ...</store>
       <nextLoc> L => L +Int 1 </nextLoc>
```

In the `storeObj` operation, we also need to store the `privateEnv` cell into the `envStackFrame`, so that when we create an object, its private members are also stored.

```k
syntax KItem ::= "envStackFrame" "(" Id "," Map "," Set ")"
syntax KItem ::= "addEnvLayer"

rule <k> addEnvLayer => .K ...</k>
     <env> Env => .Map </env>
	 <privateEnv> PE => .Set </privateEnv>
     <crntClass> Class:Id </crntClass>
     <envStack> .List => ListItem(envStackFrame(Class, Env, PE)) ...</envStack>
```

For the access of object members, we also need to know we are currently at which object when accessing a private member. It is now a new argument to the `lookupMember` function.

```k
rule <k> objectClosure(Class:Id, ListItem(envStackFrame(Class,Env,PE)) EStack)
       . X:Id 
    => lookupMember((ListItem(envStackFrame(Class,Env,PE)) EStack), X, CurClass) ...</k>
	   <crntClass> CurClass:Id </crntClass>
rule objectClosure(Class:Id, (ListItem(envStackFrame(Class':Id,_,_)) => .List) _)
     . _X:Id
  requires Class =/=K Class'
```

In the `lookupMember` function, when accessing a private member, we need to make sure that we are currently at the class where this private member is declared. If not, we just get stuck since private members are not accessible from outside the class.

```k
syntax Exp ::= lookupMember(List, Id, Id) [function]

rule lookupMember(ListItem(envStackFrame(Class, X|->L _,_)) _, X, Class) => lookup(L) 

rule lookupMember(ListItem(envStackFrame(Class', X|->L _,PE)) _, X, Class) => lookup(L) 
  requires (Class =/=K Class') andBool ((notBool (X in PE)))

rule lookupMember(ListItem(envStackFrame(_, Env, _)) Rest, X, Class) =>
     lookupMember(Rest, X, Class)
  requires notBool(X in keys(Env))
```

### 2

For dynamic semantics of typed KOOL, the modifications are similar to untyped KOOL. We only mention the differences here.

Since we now have overriding of private members, when doing dynamic dispatch, we need to first find out whether it is calling a private method inside the same class. If so, we directly look up the method in the current object's environment. If not, we do the normal lookup in the class hierarchy.

```k
rule <k> (objectClosure(_, EStack) . X
        => lookupMethodMember(EStack, EStack, X:Id, CurClass))(_:Exps) ...</k>
	   <crntClass> CurClass:Id </crntClass>

syntax Exp ::= lookupMethodMember(List,List,Id,Id)  [function]

rule lookupMethodMember((ListItem(envStackFrame(Class, (X |-> L _), PE)) _), _, X, Class) 
  => lookup(L)
  requires X in PE

rule lookupMethodMember((ListItem(envStackFrame(Class, _, PE)) _), L2, X, Class)
  => lookupMember(L2, X, Class)
  requires notBool(X in PE)

rule lookupMethodMember((ListItem(envStackFrame(Class2, _, _)) L), L2, X, CurClass)
  => lookupMethodMember(L, L2, X, CurClass)
  requires Class2 =/=K CurClass 

rule lookupMethodMember(.List, L2, X, CurClass)
  => lookupMember(L2, X, CurClass)
```

### 3

For the static semantics of typed KOOL, there are 2 cases would cause type errors related to private members. We would talk about them later one by one.
- Overriding a public method with a private method.
- Accessing a private member (no matter variable or method) of a superclass.

First, we add a new `privateEnvT` cell to keep track of all the private members when declaring a new class. 

```k
configuration <T multiplicity="?" color="yellow">
                  <tasks color="orange" multiplicity="?">
                    <task multiplicity="*" color="yellow" type="Set">
                      <k color="green"> $PGM:Stmt </k>
                      <tenv multiplicity="?" color="cyan"> .Map </tenv>
                      <ctenvT multiplicity="?" color="blue"> .Map </ctenvT>
                      <returnType multiplicity="?" color="black"> void </returnType>
                      <inClass multiplicity="?" color="Fuchsia"> .K </inClass>
					  <privateEnvT multiplicity="?" color="red"> .Set </privateEnvT> // new
                    </task>
                  </tasks>
                  <classes color="Fuchsia">
                    <classData multiplicity="*" type="Map">
                      <className color="Fuchsia"> Object </className>
                      <baseClass color="Fuchsia"> .K </baseClass>
                      <baseClasses color="Fuchsia"> .Set </baseClasses>
                      <ctenv multiplicity="?" color="blue"> .Map </ctenv>
					  <privateEnv multiplicity="?" color="red"> .Set </privateEnv>
                    </classData>
                  </classes>
                </T>
                <output color="brown" stream="stdout"> .List </output>
```

For declaration of private variables and methods, everything keeps the same with normal variable and method declaration, except that we also add its name to the `privateEnvT` cell.

```k
rule private T:Type E1:Exp, E2:Exp, Es:Exps; => private T E1; private T E2, Es;  [anywhere]
rule private T:Type X:Id = E; => private T X; X = E;                   [anywhere]

rule <k> private T:Type X:Id; => T:Type X:Id; ...</k>
	 <privateEnvT> _ (.Set => SetItem(X)) </privateEnvT>

rule <k> private T:Type F:Id(Ps:Params) S
	  => checkprivateMethod(F, getTypes(Ps)->T, C')   // checkprivateMethod would check overriding
		~> getTypes(Ps)->T F; ...</k>
	  <inClass> C </inClass>
	  <ctenvT> _ </ctenvT> // to ensure we are in a class pass
	  <privateEnvT> _ (.Set => SetItem(F)) </privateEnvT>
	  <className> C </className>
	  <baseClass> C' </baseClass>
	  (.Bag => <task>
			  <k> mkDecls(Ps) S </k>
			  <inClass> C </inClass>
			  <tenv> .Map </tenv>
			  <returnType> T </returnType>
			  </task>) 
```

When declaring a new class, we also need to create a new and empty `privateEnvT` cell.

```k
rule <task> <k> class C:Id extends C':Id { S:Stmt } => stmt ...</k> </task>
       (.Bag => <classData>...
               <className> C </className>
               <baseClass> C' </baseClass>
             ...</classData>)
       (.Bag => <task>
                <k> checkType(`class`(C')) ~> S </k>
                <inClass> C </inClass>
                <ctenvT> .Map </ctenvT>
				<privateEnvT> .Set </privateEnvT>
             </task>)
```

For the first kind of type error, we need to check whether we are overriding a public method with a private method in the `checkprivateMethod` function.

```k
  syntax KItem ::= checkprivateMethod(Id,Type,Id)

  rule <k> checkprivateMethod(F:Id, T:Type, C:Id) => checkSubtype(T, T') ...</k>
       <inClass> C </inClass>
       <className> C </className>
       <ctenv>... F |-> T':Type ...</ctenv>

  rule <k> checkprivateMethod(F:Id, T:Type, C:Id) => checkSubtype(T, T') ...</k>
       <inClass> C2 </inClass>
       <className> C </className>
       <ctenv>... F |-> T':Type ...</ctenv>
	   <privateEnv> PE </privateEnv>
    requires C =/=K C2 andBool (F in PE)

  rule <k> checkprivateMethod(F:Id, T:Type, C:Id) => stuck(checkprivateMethod(F, T, C)) ...</k>
       <inClass> C2 </inClass>
       <className> C </className>
       <ctenv>... F |-> T':Type ...</ctenv>
	   <privateEnv> PE </privateEnv>
	   <output>... .List => ListItem("Method \"" +String Id2String(F) 
	                                   +String "\" cannot be private in class \"" +String Id2String(C2)
									   +String "\" because it is public in class \"" +String Id2String(C)
									   +String "\"\n") </output>
    requires C =/=K C2 andBool notBool(F in PE)

  rule <k> checkprivateMethod(F:Id, _T:Type, (C:Id => C')) ...</k>
       <className> C </className>
       <baseClass> C':Id </baseClass>
       <ctenv> Rho </ctenv>
    requires notBool(F in keys(Rho))

  rule checkprivateMethod(_:Id,_,Object) => .K
```

For the second kind of type error, we need to check whether we are accessing a private member of a superclass when doing member access.

```k
rule <k> `class`(C:Id) . X:Id => T ...</k>
       <inClass> C </inClass>
       <className> C </className>
       <ctenv>... X |-> T:Type ...</ctenv>

  rule <k> `class`(C:Id) . X:Id => T ...</k>
       <inClass> C2 </inClass>
       <className> C </className>
       <ctenv>... X |-> T:Type ...</ctenv>
	   <privateEnv> PE </privateEnv>
    requires C =/=K C2 andBool notBool(X in PE)

  rule <k> `class`(C:Id) . X:Id => stuck(`class`(C:Id) . X) ...</k>
       <inClass> C2 </inClass>
       <className> C </className>
       <ctenv>... X |-> T:Type ...</ctenv>
	   <privateEnv> PE </privateEnv>
	   <output> ... .List => ListItem("Private member \"" +String Id2String(X) 
	                           +String "\" of class \"" +String Id2String(C)
							   +String "\" cannot be accessed in class \"" 
							   +String Id2String(C2) +String "\"\n") </output>
    requires C =/=K C2 andBool (X in PE)
```