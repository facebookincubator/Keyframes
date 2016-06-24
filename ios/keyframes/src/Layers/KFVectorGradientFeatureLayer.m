// Copyright 2004-present Facebook. All Rights Reserved.

#import "KFVectorGradientFeatureLayer.h"

#import "KFUtilities.h"
#import "KFVectorAnimation.h"
#import "KFVectorAnimationKeyValue.h"
#import "KFVectorBezierPathsHelper.h"
#import "KFVectorFeature.h"
#import "KFVectorFeatureKeyFrame.h"
#import "KFVectorGradientEffect.h"
#import "KFVectorLayerHelper.h"

@implementation KFVectorGradientFeatureLayer
{
  KFVectorFeature *_feature;
  NSArray *_keyFramePaths;
  NSArray *_keyTimes;
  CAGradientLayer *_gradientLayer;
}

static void setupGradientLayerWithEffect(CAGradientLayer *gradientLayer, KFVectorGradientEffect *gradientEffect, CGSize canvasSize)
{
  // Colors key frame animation
  // Build color start/end pairs
  UIColor *startColor = KFColorWithHexString([[[[gradientEffect colorStart] keyValues] firstObject] keyValue]);
  UIColor *endColor = KFColorWithHexString([[[[gradientEffect colorEnd] keyValues] firstObject] keyValue]);
  gradientLayer.colors = @[(id)startColor.CGColor, (id)endColor.CGColor];
}

- (void)setFeature:(KFVectorFeature *)feature canvasSize:(CGSize)canvasSize
{
  // Make sure feature has a gradient effect
  NSParameterAssert(feature && feature.gradientEffect);

  if ([feature.gradientEffect.gradientTypeString isEqualToString:@"linear"]) {
    _feature = feature;
    CAShapeLayer *gradientMaskLayer = [CAShapeLayer layer];
    gradientMaskLayer.frame = self.bounds;
    gradientMaskLayer.fillColor = feature.fillColor.CGColor;
    gradientMaskLayer.strokeColor = feature.strokeColor.CGColor;
    gradientMaskLayer.lineWidth = feature.strokeWidth * MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    if (feature.strokeColor) {
      gradientMaskLayer.lineCap = kCALineCapRound;
    }
    gradientMaskLayer.path = KFVectorBezierPathsFromCommandList([[feature.keyFrames firstObject] paths], canvasSize, self.bounds.size).CGPath;

    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.frame = self.bounds;
    setupGradientLayerWithEffect(_gradientLayer, feature.gradientEffect, canvasSize);
    _gradientLayer.mask = gradientMaskLayer;
    [self addSublayer:_gradientLayer];
    [self _addAnimations];
  } else {
    NSAssert(@"Unknown gradient type passed in: %@", feature.gradientEffect.gradientTypeString);
  }
}

- (void)_addAnimations
{
  NSMutableArray *colorsArray = [NSMutableArray array];
  for (int x = 0; x < MAX(_feature.gradientEffect.colorStart.keyValues.count, _feature.gradientEffect.colorEnd.keyValues.count); x++) {
    NSUInteger startColorIndex = x;
    if (_feature.gradientEffect.colorStart.keyValues.count <= startColorIndex) {
      startColorIndex = _feature.gradientEffect.colorStart.keyValues.count - 1;
    }
    UIColor *startColor = KFColorWithHexString([[[[_feature.gradientEffect colorStart] keyValues] objectAtIndex:startColorIndex] keyValue]);

    NSUInteger endColorIndex = x;
    if (_feature.gradientEffect.colorEnd.keyValues.count <= endColorIndex) {
      endColorIndex = _feature.gradientEffect.colorEnd.keyValues.count - 1;
    }
    UIColor *endColor = KFColorWithHexString([[[[_feature.gradientEffect colorEnd] keyValues] objectAtIndex:endColorIndex] keyValue]);

    [colorsArray addObject:@[(id)startColor.CGColor, (id)endColor.CGColor]];
  }

  CAKeyframeAnimation *colorAnimation = [CAKeyframeAnimation animationWithKeyPath:@"colors"];
  colorAnimation.duration = _feature.gradientEffect.colorStart.animationFrameCount * 1.0 / _feature.gradientEffect.colorStart.frameRate;
  colorAnimation.repeatCount = HUGE_VALF;
  colorAnimation.values = colorsArray;

  KFVectorAnimation *animationToUseForTimingCurve = _feature.gradientEffect.colorStart;
  if (_feature.gradientEffect.colorEnd.timingCurves.count == colorsArray.count - 1) {
    animationToUseForTimingCurve = _feature.gradientEffect.colorEnd;
  }
  colorAnimation.timingFunctions = KFVectorLayerMediaTimingFunction(animationToUseForTimingCurve.timingCurves);
  colorAnimation.keyTimes = KFMapArray(animationToUseForTimingCurve.keyValues, ^id(KFVectorAnimationKeyValue *keyValue) {
    return @(keyValue.startFrame * 1.0 / animationToUseForTimingCurve.animationFrameCount);
  });

  [_gradientLayer addAnimation:colorAnimation forKey:@"gradient color animation"];
}

@end
