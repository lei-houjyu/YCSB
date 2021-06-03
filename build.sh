mvn -pl rocksdb -am clean package  -Dmaven.test.skip=true
rm rocksdb/target/dependency/rocksdbjni-6.2.2.jar
cp with-compaction.jar rocksdb/target/dependency/rocksdbjni-6.14.0.jar
