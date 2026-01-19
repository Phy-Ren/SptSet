Auther: Tian YUAN

The most basic data structure in GAP is called `object`. Almost everything in GAP is an `object`. `Object` has a complex hierarchy of structures, hopefully I can give a clear explaination in the following.

An `object` has `type` and `data`. As shown by their names, `type` is a collection of objects that the object belongs to, and `data` is the data about the object that we should store. `Data` is easy to understand, its form is determined by `type`, and in most cases we don't deal with it directly. `Type` system in GAP is very complicated, `type` is our main focus.

`Type` has `family` and `filter`. `Family` is an object that is used to store some complicated information about the `type`. `Filter` is a function, (to be precise, an operation,) that returns `true` or `false`, a `filter` should have the name of the form of `IsXXX`, and `IsXXX(a)` tells us if `a` is `XXX`. There is a huge poset of `filters` in GAP, when we define a new `filter`, we should determine the superior of it. For example, if we want to define `IsAbelianGroup`, then its superior should contain `IsGroup`. `Filter` can also be applied with logical operations. For example, we can also define `IsAbelianGroup` to be `IsGroup and IsAbelian`, if they exist.

If we only care about the computer scientific properties of `object`, then we have done, there is no more to say. But GAP is a computer algebra system, we have to add more hierachies to describe some subtle relations in math.

To construct a mathematical `object` in computer, we should determine what is the abstract concept that the `object` represents, and what kind of `data` should we store to represent that abstract concept. The first one is determined by `category` and the second one is determined by `representation`. Both of them are special kind of `filters` that are huge subposets of the total poset of `filters`. The `filter` used to construct a `type` should have the form of `X and Y`, where `X` is a `category` and `Y` is a `representation`. In practice, it is quite painful to find an appropriate position for the `X` and `Y` of a new `object`, but it is cost of using the powerful functions in GAP.

Examples of `category` includes structured sets `IsGroup`, `IsRing`, and also elements in some set `IsMultiplicativeElement`.

`Representation` determines how to store `data`. For example, `IsPositionalObjectRep` means using `list` to store `data`. And `IsComponentObjectRep` means using `record` to store `data`. There is an important subrepresentation of `IsComponentObjectRep` called `IsAttributeStoringRep`, it introduces a concept called `attribute`, we will talk about it later. To remind you, except some inner-built objects, all objects should be a subrepresentation of either `IsPositionalObjectRep` or `IsComponentObjectRep`.

The advantage of this `type` system is we can use `operation`. `operation` is a special kind of functions that each of its input is attached with a `filter`. Two traditional functions must have different name, but two `operations` can have the same name but with different inputs with different attached `filters`. When call the name of an `operation`, the real called function depends on the input you give. For example, if we want to find all normal subgroups of a group, for different kinds of groups and representations, we have different algorithm to calculate them, but we still want to use the name `NormalSubgroups`. The ability to use different methods to solve the problem makes it easy to extend the system.

If an object is in `IsAttributeStoringRep`, we could attach `attributes` to the object. `Attributes` are just `operations` stored in an `object`. Once we call an `attribute`, the calculation result will be stored. And the next time we call the same `attribute`, it will use the result that has already been calculated. If the output of an `attribute` is either `true` or `false`, we call it `property`. Notice that `property` is a special kind of `filter`, and `filter` is actually a special kind of `operation`.

That's all. Let's finish this note with a summary. To construct a new `object`:
We need to determine `type` and `data`.
- `Type` has `family` and `filter`.
    - `Family` is also an `object`, so we go back to the start point.
    - `Filter` has `category` and `representation`.
        - `Category` is abstract collection of mathematics objects.
        - `Representation` determines how to represent the mathematics objects in computer.
- `Data` is determined by `representation`. For example, if it is `IsPositionalObjectRep`, the `data` is just a list.
