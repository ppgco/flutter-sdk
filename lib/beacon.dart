import 'dart:convert';

class Tag {
  late String key;
  late String value;
  late int ttl;
  late String strategy;

  static Tag fromString(String legacyTag) {
    final parts = legacyTag.split(':');
    String key, value;
    if (parts.length == 2) {
      key = parts[0];
      value = parts[1];
    } else {
      key = 'default';
      value = parts[0];
    }

    return Tag(
      key: key,
      value: value,
      ttl: 0,
      strategy: "append",
    );
  }

  Tag({
    required this.key,
    required this.value,
    required this.ttl,
    required this.strategy,
  });

  Map<String, dynamic> serialize() {
    return {
      'key': key,
      'value': value,
      'ttl': ttl,
      'strategy': strategy,
    };
  }
}

class Beacon {
  late Set<Tag> tags;
  late Set<Tag> tagsToDelete;
  late Map<String, dynamic> selectors;
  late String? customId;
  late String? assignToGroup;
  late String? unassignFromGroup;

  Beacon({
    required this.tags,
    required this.tagsToDelete,
    required this.customId,
    required this.selectors,
    this.assignToGroup,
    this.unassignFromGroup,
  });

  String serialize() {
    final Map<String, dynamic> data = {
      'tags': tags.map((item) => item.serialize()).toList(),
      'tagsToDelete': tagsToDelete.map((item) => item.serialize()).toList(),
      'selectors': selectors,
      'customId': customId,
    };
    
    if (assignToGroup != null) {
      data['assignToGroup'] = assignToGroup;
    }
    if (unassignFromGroup != null) {
      data['unassignFromGroup'] = unassignFromGroup;
    }
    
    return jsonEncode(data);
  }
}