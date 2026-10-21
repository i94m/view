<template>
  <view v-show="visible">
    <div id="chart" style="width: 100%; height: 120px;margin: 120px auto 0;"></div>
  </view>
</template>

<script setup>
// 只按需引入 graphic 组件 + canvas 渲染器：整包 echarts 会把首页 chunk 撑到 1MB+
import * as echarts from "echarts/core";
import { GraphicComponent } from "echarts/components";
import { CanvasRenderer } from "echarts/renderers";
import {onMounted, ref, reactive} from "vue";

echarts.use([GraphicComponent, CanvasRenderer]);

const texts = ref([
  '宝剑锋从磨砺出，梅花香自苦寒来。',
  '青春由磨砺而出彩，人生因奋斗而升华。',
  '既然选择远方，当不负青春，砥砺前行。',
  '只有极致的拼搏，才能配得上极致的风景。',
  '你可以一无所有，但绝不能一无是处。',
  '抱怨身处黑暗，不如提灯前行。',
  '心态决定高度，细节决定成败。',
  '过去的价值不代表未来的地位。',
  '山重水复疑无路，柳暗花明又一村。',
  '千磨万击还坚劲，任尔东西南北风。',
  '长风破浪会有时，直挂云帆济沧海。',
  '不积跬步，无以至千里；不积小流，无以成江海。',
  '天道酬勤，厚德载物。',
  '志存高远，脚踏实地。',
  '书山有路勤为径，学海无涯苦作舟。',
  '业精于勤荒于嬉，行成于思毁于随。',
  '路漫漫其修远兮，吾将上下而求索。',
  '欲穷千里目，更上一层楼。',
  '会当凌绝顶，一览众山小。',
  '海纳百川，有容乃大；壁立千仞，无欲则刚。',
  '不畏将来，不念过往，心有猛虎，细嗅蔷薇。',
  '人生如逆水行舟，不进则退。',
  '莫愁前路无知己，天下谁人不识君。',
  '春蚕到死丝方尽，蜡炬成灰泪始干。'
]);

const randomText = () => {
  return texts.value[Math.floor(Math.random() * texts.value.length)];
}

const selectedText = randomText();

const visible = ref(true);
const option = reactive({
  graphic: {
    elements: [
      {
        type: 'text',
        left: 'center',
        top: 'center',
        style: {
          text: selectedText,
          fontSize: 36,
          fontWeight: 'normal',
          lineDash: [0, 300],
          lineDashOffset: 0,
          fill: 'transparent',
          stroke: 'white',
          lineWidth: 1
        },
        keyframeAnimation: {
          duration: 2000,
          loop: false,
          keyframes: [
            {
              percent: 0.6,
              style: {
                fill: 'transparent',
                lineDashOffset: 200,
                lineDash: [300, 0]
              }
            },
            {
              // Stop for a while.
              percent: 0.8,
              style: {
                fill: 'transparent'
              }
            },
            {
              percent: 1,
              style: {
                fill: 'white'
              }
            }
          ]
        }
      }
    ]
  }
});

const myChart = ref(null);

const echartInit = () => {
  myChart.value = echarts.init(document.getElementById("chart"));
  updateChart();
};

const updateChart = () => {
  visible.value = document.documentElement.clientWidth > 960;
  if (visible.value) {
    myChart.value.setOption(option);
  }
}

onMounted(() => {
  echartInit();

  window.onresize = () => {
    updateChart();
  };
});
</script>

<style scoped>
</style>