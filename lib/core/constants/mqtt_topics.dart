class MqttTopics {
  // Updated topic patterns for new telegraf.conf format
  static const String sensorTopic = 'grow/+/sensor';
  static const String actuatorTopic = 'grow/+/actuator';
  static const String deviceTopic = 'grow/+/device';
  static const String allTopics = 'grow/+/+';

  static String sensorTopicFor(String deviceNode) => 'grow/$deviceNode/sensor';
  static String actuatorTopicFor(String deviceNode) =>
      'grow/$deviceNode/actuator';
  static String deviceTopicFor(String deviceNode) => 'grow/$deviceNode/device';

  // TODO: Implement command topics when actuator control feature is added
  // static String actuatorCommandTopicFor(String deviceNode) => 'grow/$deviceNode/actuator/set';
}
