class Feed{
  public int feedId;

  public Feed(int feedId){
    this.feedId = feedId;
  }
}

List<Feed> feeds = new ArrayList<>();
for (int i = 0; i < 10; i++) {
  feeds.add(new Feed(i))
}

for (int i = 0; i < 10; i++) {
//  Feed feed = feeds.get(i)
//  feed.feedId = i + 1
}

for (int i = 0; i < 10; i++) {
  print feeds.get(i).feedId
}


