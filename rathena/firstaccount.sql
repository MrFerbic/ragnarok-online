INSERT INTO `login` (
  `account_id`, `userid`, `user_pass`, `sex`, `email`, `group_id`, `state`, `unban_time`, `expiration_time`,
  `logincount`, `lastlogin`, `last_ip`, `birthdate`, `character_slots`, `pincode`, `pincode_change`,
  `vip_time`, `old_group`, `web_auth_token`, `web_auth_token_enabled`
) VALUES (
  2000000, 'admin', 'admin123', 'F', 'admin@athena.com', 99, 0, 0, 0,
  5, '2025-05-18 01:17:10', '192.168.0.100', NULL, 0, '1412', 1747530571,
  0, 0, 'ce6a6fa2899bbf24', 0
)
ON DUPLICATE KEY UPDATE
  `userid` = VALUES(`userid`),
  `user_pass` = VALUES(`user_pass`),
  `sex` = VALUES(`sex`),
  `email` = VALUES(`email`),
  `group_id` = VALUES(`group_id`),
  `state` = VALUES(`state`),
  `unban_time` = VALUES(`unban_time`),
  `expiration_time` = VALUES(`expiration_time`),
  `logincount` = VALUES(`logincount`),
  `lastlogin` = VALUES(`lastlogin`),
  `last_ip` = VALUES(`last_ip`),
  `birthdate` = VALUES(`birthdate`),
  `character_slots` = VALUES(`character_slots`),
  `pincode` = VALUES(`pincode`),
  `pincode_change` = VALUES(`pincode_change`),
  `vip_time` = VALUES(`vip_time`),
  `old_group` = VALUES(`old_group`),
  `web_auth_token` = VALUES(`web_auth_token`),
  `web_auth_token_enabled` = VALUES(`web_auth_token_enabled`);