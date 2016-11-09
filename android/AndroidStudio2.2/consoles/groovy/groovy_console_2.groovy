public static int getTranslateX(float degree, int distance) {
  return Double.valueOf(distance * Math.cos(Math.toRadians(degree))).intValue();
}

public static int getTranslateY(float degree, int distance) {
  return Double.valueOf(-1 * distance * Math.sin(Math.toRadians(degree))).intValue();
}

System.out.println(getTranslateX(45, 100));
System.out.println(getTranslateX(90, 100));
System.out.println(getTranslateX(180, 100));