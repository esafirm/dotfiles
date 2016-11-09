import rx.Observable
import rx.functions.Action1
import rx.functions.Func1

Observable.just(1, 2, 3, 4)
    .switchMap(new Func1<Integer, Observable>() {
  @Override
  Observable call(Integer integer) {
    return Observable.error(new NullPointerException())
  }
})
    .onErrorReturn(new Func1() {
  @Override
  Object call(Object o) {
    return null
  }
})
    .subscribe(new Action1() {
  @Override
  void call(Object o) {
    System.out.print(o.toString())
  }
})