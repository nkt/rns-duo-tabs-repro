import { StyleSheet, Text, View } from 'react-native';
import { version } from 'react-native-screens/package.json';

export function TabScreen({ title }) {
  return (
    <View style={styles.root}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.caption}>react-native-screens {version}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#f2f2f7' },
  title: { fontSize: 28, fontWeight: '700' },
  caption: { marginTop: 8, fontSize: 15, color: '#666' },
});
