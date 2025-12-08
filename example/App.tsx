/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */
import React, { useRef } from 'react';
import { StatusBar, useColorScheme, View } from 'react-native';
import { NitroSpoiler } from 'react-native-spoiler';

function App() {
  const isDarkMode = useColorScheme() === 'dark';
  const ref = useRef(null);

  return (
    <View>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <NitroSpoiler
        style={{ width: 100, height: 100, backgroundColor: 'red' }}
        ref={ref}
      />
    </View>
  );
}

export default App;
