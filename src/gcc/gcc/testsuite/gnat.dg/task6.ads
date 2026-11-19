package Task6 is

  type Int is task interface;

  procedure E (T: Int) is abstract;

  task type T is new Int with
    entry E;
  end T;

  function Make return T;

end Task6;
