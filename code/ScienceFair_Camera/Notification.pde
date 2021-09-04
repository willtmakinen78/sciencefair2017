import twitter4j.conf.*;                            //import java and twitter libraries
import twitter4j.*;
import twitter4j.auth.*;
import twitter4j.api.*;
import java.util.*;

import java.text.DateFormat;
import java.text.SimpleDateFormat;

import http.requests.*;

class Notification {
  GetRequest failureNotification;                    //create objects for each library
  twitter4j.Twitter twitter;
  List<Status> tweets;
  Status status;
  Status firstStatus;
  Date firstTweetDate;
  Date tweetDate;

  String[] lines;                                   //other variables
  String searchString;

  boolean stopped = false;

  int startHour;
  int startMinute;
  int startSecond;
  int tweetHour;
  int tweetMinute;
  int tweetSecond;

  String firstTweetText;
  String tweetText;

  long startMillis;

  Notification(String filename) {                                //initialization function, load the keys/tokens from the config file
    lines = loadStrings(filename);

    ConfigurationBuilder cb = new ConfigurationBuilder();
    cb.setOAuthConsumerKey(lines[0]);
    cb.setOAuthConsumerSecret(lines[1]);
    cb.setOAuthAccessToken(lines[2]);
    cb.setOAuthAccessTokenSecret(lines[3]);

    searchString = lines[4];

    TwitterFactory tf = new TwitterFactory(cb.build());                            //create instances of the library
    twitter = tf.getInstance();

    failureNotification = new GetRequest(trim(lines[5]));
  }
  void sendNotification() {
    failureNotification.send();                                                    //uses pushingbox to notify of failures
  }
  void update() {
    try {                                                                          //search for the # and get a list of the top tweets
      Query query = new Query(searchString);
      QueryResult result = twitter.search(query);
      tweets = result.getTweets();
    }
    catch (TwitterException te) {
      System.out.println("Failed to search tweets: " + te.getMessage());
      System.exit(-1);
    }
  }
  void getFirstTweet() {                                                          //save the time of the first tweet upon starting the analysis to compare against tweets sent afterwards
    update();
    try {
      firstStatus = tweets.get(0);
    }
    catch(Exception e) {
      println(e);
    }
    firstTweetDate = firstStatus.getCreatedAt();
    startMillis = millis();
  }
  void checkForStop() {
    if (millis() - startMillis > 90000) {                                                //twitter only lets you access its API 15 times every 15 minutes, only update every 90 seconds to avoid getting locked out
      update();
      status = tweets.get(0);
      tweetDate = status.getCreatedAt();

      DateFormat formattedStartDate = new SimpleDateFormat("yyyy-mm-dd hh:mm:ss");      //changh the time information into a useable format
      DateFormat formattedTweetDate = new SimpleDateFormat("yyyy-mm-dd hh:mm:ss");
      String startDateString = formattedStartDate.format(firstTweetDate);
      String tweetDateString = formattedTweetDate.format(tweetDate);

      if (startDateString.equals(tweetDateString) != true) {                            //compare the most recent tweet's time to that of the first one
        stopped = true;
        println("Print remotely stopped");
      } else {
        stopped = false;
        println("No stop commands sent since last update");
      }
      startMillis = millis();
    }
  }
}