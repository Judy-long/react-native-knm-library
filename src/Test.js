import React, {Component} from 'react';
import { NativeModules, Platform, StatusBar, View } from 'react-native';

export default class Test extends Component {
    props: any;
    constructor(props: any) {
        super(props);
        this.props = props;
        // const hostKey = props.hostKey;
        const hostKey = "qa"
        //根据打包配置来设置当前环境
        // changeConfig(hostKey);

    }


    render() {
        return (
            <View>
                <Text>
                    dad
                </Text>
            </View>
        );
    }
}
