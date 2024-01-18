//
//  LyzZMetaxParaboloidButton.m
//  MetalCurvedSurfaceDemo
//
//  Created by WangWang on 2021/6/10.
//

#import "LyzZMetaxParaboloidButton.h"
#import "LyzZMetaxParaboloidPipeline.h"
#import "LyzZMetaxParaboloidTypes.h"
#import "LyzZMetaxParaboloidMath.h"
#include <pthread.h>

static NSString *kLyzZMetaxParaboloidRunloopMode = @"LyzZMetaxParaboloidRunloopMode";

static const NSUInteger kLyzZVzxBtnSampNumber = 60;
static const NSUInteger kLyzZVzxBtnVertexListCount = 61;

static struct {
    struct {
        CGFloat power;
        CGFloat rpower;
        CGFloat a;
        CGFloat b;
    } squircle;
    
    struct {
        UInt32 u;
        UInt32 v;
        UInt32 w;
    }color;
    
    float zNear;
    float zFar;
} kLyzZMetaxParaboloidButtonValue = {
    .squircle.power   = 2.7,
    .squircle.rpower = 2.7,
    .squircle.a = 5,
    .squircle.b = 5,
    .zNear = 0.001,
    .zFar = 20,
    .color.u =
    // 0x00ff00,
    0x1385FFF, /// 0表示透明度从0到1，实际的颜色值为385FFF，蓝色
    .color.v =
    // 0x1ff0000,
    0x7938FF, /// 1表示透明度从1到0，实际的颜色值为7938FF，紫色
    .color.w =
    // 0x10000ff
    0x1AA38FF, /// 1表示透明度从1到0，实际的颜色值为AA38FF，粉色
};

static dispatch_queue_t LyzZMetaxMetalVertexQueue(void) {
    static dispatch_queue_t queue;
    if (!queue) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
        queue = dispatch_queue_create("com.baidu.lyzzvs.metal.vertex", attr);
    }
    return queue;
}

@interface LyzZVzxMetalWeakProxy : NSProxy
@property (nullable, nonatomic, weak) id target;
- (instancetype)initWithTarget:(id)target;
+ (instancetype)proxyWithTarget:(id)target;
@end

@implementation LyzZVzxMetalWeakProxy
- (instancetype)initWithTarget:(id)target {
    _target = target;
    return self;
}

+ (instancetype)proxyWithTarget:(id)target {
    return [[LyzZVzxMetalWeakProxy alloc] initWithTarget:target];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return _target;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    void *null = NULL;
    [invocation setReturnValue:&null];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [_target respondsToSelector:aSelector];
}

- (BOOL)isEqual:(id)object {
    return [_target isEqual:object];
}

- (NSUInteger)hash {
    return [_target hash];
}

- (Class)superclass {
    return [_target superclass];
}

- (Class)class {
    return [_target class];
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [_target isKindOfClass:aClass];
}

- (BOOL)isMemberOfClass:(Class)aClass {
    return [_target isMemberOfClass:aClass];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return [_target conformsToProtocol:aProtocol];
}

- (BOOL)isProxy {
    return YES;
}

- (NSString *)description {
    return [_target description];
}

- (NSString *)debugDescription {
    return [_target debugDescription];
}
@end

#pragma mark - LyzZMetaxParaboloidButton
/// ##############################################################################
/// ##############################################################################
/// ---------- LyzZMetaxParaboloidButton ----------
/// ##############################################################################
/// ##############################################################################
@interface LyzZMetaxParaboloidButton (/*subviews*/) <LyzZMetaxParaboloidPipelineDelegate>
@property (nonatomic, strong) LyzZMetaxParaboloidPipeline *uPipeline;
@property (nonatomic, strong) LyzZMetaxParaboloidPipeline *vPipeline;
@property (nonatomic, strong) LyzZMetaxParaboloidPipeline *wPipeline;
@end

@interface LyzZMetaxParaboloidButton () {
    CADisplayLink *_displayLink;
}
@property (nonatomic, assign) NSTimeInterval lastFrameTime;
@end

@interface LyzZMetaxParaboloidButton ()
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLLibrary> library;
@property (nonatomic, strong) MTLRenderPassDescriptor *renderDescriptor;
@property (nonatomic, strong) id<MTLRenderPipelineState> plState;
@property (nonatomic, strong) id<MTLDepthStencilState> depthState;
@property (nonatomic, strong) id <MTLTexture> depthTexture;
@property (nonatomic, assign) MTLViewport viewPort;
@property (nonatomic, copy) NSArray <NSNumber *> *colors;
@end

@interface LyzZMetaxParaboloidButton ()
@property (nonatomic, weak) LyzZMetaxParaboloidAnimationStrategy *animationStartegy;
@property (nonatomic, strong) LyzZMetaxParaboloidNormalAnimationStrategy *normalStrategy;
@property (nonatomic, strong) LyzZMetaxParaboloidListenningAnimationStrategy *listenningStrategy;
@property (nonatomic, strong) LyzZMetaxParaboloidLoadingAnimationStrategy *loadingStrategy;
@property (nonatomic, strong) LyzZMetaxParaboloidTransitionAnimationStrategy *transitionStrategy;
@end

@implementation LyzZMetaxParaboloidButton {
    __weak NSThread *_renderThread;
    BOOL _continueRunLoop;
    BOOL _modelReady;
    /// 所有的顶点buffer
    id <MTLBuffer> _verticesBuffer;
    LyzZVzxParaboloidVertex _verticesPointer[kLyzZVzxBtnVertexListCount][kLyzZVzxBtnVertexListCount];
    /// 三角形绘制顶点顺序buffer
    id <MTLBuffer> _primitivesIndexBuffer;
    /// 深度
    id <MTLTexture> _depthTexture;
    vector_uint2 _viewportSize;
    /// animationStrategyLock
    NSLock *_animationStrategyLock;
    pthread_rwlock_t _modelRWLock;
}

- (void)dealloc {
    pthread_rwlock_destroy(&_modelRWLock);
    [self stopRenderLoop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame colors:(NSArray <NSNumber *> *)colors {
    if (self = [super initWithFrame:frame]) {
        [self updateColor:colors];
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self =  [super initWithFrame:frame]) {
        [self updateColor:@[]];
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self updateColor:@[]];
        [self setup];
    }
    return self;
}

- (void)setup {
    pthread_rwlock_init(&_modelRWLock, NULL);
    _modelReady = NO;
    self.framesPerSecond = 30;
    _animationStrategyLock = [NSLock new];
    [self setupMetalPipelines];
    _metalLayer = (CAMetalLayer *)self.layer;
    /// CAMetalLayer的opaque属性默认为true。为了能够让colorattachment的alpha生效，这里需要设置为false；
    _metalLayer.opaque = false;
    self.layer.delegate = self;
    if (![self setupDevice]) {
        return;
    }
    if (![self setupLibrary]) {
        return;
    }
    if (![self setupCommandQueue]) {
        return;
    }
    _metalLayer.device = self.device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    [self setupPipeline];
    [self setupDepthStencilDescriptor];
    [self setupRenderPassDescriptor];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    self.lastFrameTime = CFAbsoluteTimeGetCurrent();
    [self resizeDrawable:self.window.screen.nativeScale];
    [self setupVertex];
}

- (void)setupMetalPipelines {
    self.animationStartegy = self.normalStrategy;
    _uPipeline = [[LyzZMetaxParaboloidPipeline alloc] init];
    _uPipeline.currentIndex = 0;
    _uPipeline.delegate = self;
    _uPipeline.rotateValue = [self.animationStartegy rotateStartValueFor:_uPipeline];
    
    _vPipeline = [[LyzZMetaxParaboloidPipeline alloc] init];
    _vPipeline.currentIndex = 1;
    _vPipeline.delegate = self;
    _vPipeline.rotateValue = [self.animationStartegy rotateStartValueFor:_vPipeline];
    
    _wPipeline = [[LyzZMetaxParaboloidPipeline alloc] init];
    _wPipeline.currentIndex = 2;
    _wPipeline.delegate = self;
    _wPipeline.rotateValue = [self.animationStartegy rotateStartValueFor:_wPipeline];
}

- (BOOL)setupDevice {
    if (_device) {
        return YES;
    }
    _device = MTLCreateSystemDefaultDevice();
    do {
        if (!_device) {
            return NO;
        }
    } while (0);
    return YES;
}

- (BOOL)setupCommandQueue {
    if (_commandQueue) {
        return YES;
    }
    _commandQueue = [_device newCommandQueue];
    return (_commandQueue != nil);
}

- (BOOL)setupLibrary {
    if (_library) {
        return YES;
    }
    
#ifdef Metal_pch
    _library = [_device newDefaultLibrary];
#else
    _library = [_device newDefaultLibraryWithBundle:[MISMetaxBundle resourcesBundle] error:nil];
#endif
    return (_library != nil);
}

- (void)setupRenderPassDescriptor {
    _renderDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    /// color
    _renderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    _renderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    /// depth
    _renderDescriptor.depthAttachment.clearDepth = 1.0;
    _renderDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
}

- (MTLVertexDescriptor *)setupPipelineVertexDescriptor {
    /*
    https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Render-Ctx/Render-Ctx.html#//apple_ref/doc/uid/TP40014221-CH7-SW44
     */
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor vertexDescriptor];
    /// position
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[0].offset = 0;
    /// ucolor
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.attributes[1].offset = sizeof(vector_float4);
    /// vcolor
    vertexDescriptor.attributes[2].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[2].bufferIndex = 0;
    vertexDescriptor.attributes[2].offset = 2 * sizeof(vector_float4);
    /// wcolor
    vertexDescriptor.attributes[3].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[3].bufferIndex = 0;
    vertexDescriptor.attributes[3].offset = 3 * sizeof(vector_float4);
    /// stride
    vertexDescriptor.layouts[0].stride = sizeof(LyzZVzxParaboloidVertex);
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    return vertexDescriptor;
}

- (MTLRenderPipelineColorAttachmentDescriptor *)setupPipelineBlendDescriptor:(MTLRenderPipelineColorAttachmentDescriptor *)blendAttachment {
    /*
     https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Render-Ctx/Render-Ctx.html#//apple_ref/doc/uid/TP40014221-CH7-SW22
     Blending uses a highly configurable blend operation to mix the output returned by the fragment function (src) with pixel values in the attachment (dest).
     颜色混合，比如alpha透明度。
     dest: the color already in the renderbuffer (vertex color)
     src: the fragment currently being shaded (clear color)
     RGB = src.rgb * src_factor  + dest.rgb * dest_factor;
     在这里的话：
     RGB = src.rgb * src.alpha + dest.rgb * (1-src.alpha)
     */
    blendAttachment.pixelFormat = self.metalLayer.pixelFormat;
    blendAttachment.blendingEnabled = YES;
    blendAttachment.rgbBlendOperation = MTLBlendOperationAdd;
    blendAttachment.alphaBlendOperation = MTLBlendOperationAdd;
    blendAttachment.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    blendAttachment.sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    blendAttachment.destinationRGBBlendFactor =
           MTLBlendFactorOneMinusSourceAlpha; /// OneMinus : 1 -
    blendAttachment.destinationAlphaBlendFactor =
           MTLBlendFactorOneMinusSourceAlpha;
    return blendAttachment;
}

- (void)setupDepthStencilDescriptor {
    /// https://metalbyexample.com/up-and-running-3/
    /// Depth and Stencil State
    MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = YES;
    _depthState = [self.device newDepthStencilStateWithDescriptor:depthDescriptor];
}

- (void)setupDepthTexture:(CGSize)size {
    if (self.metalLayer == nil) {
        return;
    }
    if (fabs([self.depthTexture width] - size.width) > 1.0 ||
        fabs([self.depthTexture height] - size.height) > 1.0) {
        MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:size.width height:size.height mipmapped:NO];
        desc.usage = MTLTextureUsageRenderTarget;
        desc.storageMode = MTLStorageModePrivate;
        self.depthTexture = [self.metalLayer.device newTextureWithDescriptor:desc];
    }
}

- (void)setupPipeline {
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    /// shader
    pipelineDescriptor.vertexFunction = [self.library newFunctionWithName:@"paraboloidVertexShader"];
    pipelineDescriptor.fragmentFunction = [self.library newFunctionWithName:@"paraboloidFragmentShader"];
    /// blend
    MTLRenderPipelineColorAttachmentDescriptor *blendAttachment = pipelineDescriptor.colorAttachments[0];
    pipelineDescriptor.colorAttachments[0] = [self setupPipelineBlendDescriptor:blendAttachment];
    /// vertex
    pipelineDescriptor.vertexDescriptor = [self setupPipelineVertexDescriptor];
    /// depth
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    NSError *error;
    @synchronized (self) {
        _plState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    }
}

- (void)setupVertex {
    dispatch_async(LyzZMetaxMetalVertexQueue(), ^{
        if (!self) {
            return;
        }
        [self buildVertices];
        if (![self buildPrimitivesIndexBuffer]) {
            return;
        }
        if (0 == pthread_rwlock_trywrlock(&self->_modelRWLock)) {
            self->_modelReady = YES;
            pthread_rwlock_unlock(&self->_modelRWLock);
        }
    });
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window == nil || self.superview == nil) {
        [_displayLink invalidate];
        _displayLink = nil;
        return;
    }
    [self setupDisplayLinkForScreen:self.window.screen];
    @synchronized (self) {
        _continueRunLoop = NO;
    }
    LyzZVzxMetalWeakProxy *proxy = [LyzZVzxMetalWeakProxy proxyWithTarget:self];
    NSThread *localThread = [[NSThread alloc] initWithTarget:proxy selector:@selector(runThread) object:nil];
    localThread.name = @"com.lyzzvzx.metalRender";
    _continueRunLoop = YES;
    [localThread start];
    _renderThread = localThread;
}

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)displayLayer:(CALayer *)layer {
    [self renderOnEvent];
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    [self renderOnEvent];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    [self renderOnEvent];
}

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor {
    [super setContentScaleFactor:contentScaleFactor];
    [self resizeDrawable:self.window.screen.nativeScale];
}

#pragma mark - setter and getter
- (void)setPaused:(BOOL)paused {
    _paused = paused;
    _displayLink.paused = paused;
}

- (void)setFramesPerSecond:(NSInteger)framesPerSecond {
    _framesPerSecond = framesPerSecond;
    self.uPipeline.framesPerSecond = _framesPerSecond;
    self.vPipeline.framesPerSecond = _framesPerSecond;
    self.wPipeline.framesPerSecond = _framesPerSecond;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)setAnimationStartegy:(LyzZMetaxParaboloidAnimationStrategy *)animationStartegy {
    [_animationStrategyLock lock];
    _animationStartegy = animationStartegy;
    [_animationStrategyLock unlock];
}

- (LyzZMetaxParaboloidNormalAnimationStrategy *)normalStrategy {
    if (!_normalStrategy) {
        _normalStrategy = [[LyzZMetaxParaboloidNormalAnimationStrategy alloc] initWithFPS:self.framesPerSecond];
        _normalStrategy.next = self.transitionStrategy;
    }
    return _normalStrategy;
}

- (LyzZMetaxParaboloidListenningAnimationStrategy *)listenningStrategy {
    if (!_listenningStrategy) {
        _listenningStrategy = [[LyzZMetaxParaboloidListenningAnimationStrategy alloc] initWithFPS:self.framesPerSecond];
        _listenningStrategy.next = self.transitionStrategy;
    }
    return _listenningStrategy;
}

- (LyzZMetaxParaboloidLoadingAnimationStrategy *)loadingStrategy {
    if (!_loadingStrategy) {
        _loadingStrategy = [[LyzZMetaxParaboloidLoadingAnimationStrategy alloc] initWithFPS:self.framesPerSecond];
        _loadingStrategy.next = self.transitionStrategy;
    }
    return _loadingStrategy;
}

- (LyzZMetaxParaboloidTransitionAnimationStrategy *)transitionStrategy {
    if (!_transitionStrategy) {
        _transitionStrategy = [[LyzZMetaxParaboloidTransitionAnimationStrategy alloc] initWithFPS:self.framesPerSecond];
    }
    return _transitionStrategy;
}

#pragma mark - private
- (void)updateColor:(NSArray <NSNumber *> *)colors {
    if (colors && [colors isKindOfClass:[NSArray class]]) {
        NSMutableArray <NSNumber *> *cls = [NSMutableArray arrayWithArray:@[
            @(kLyzZMetaxParaboloidButtonValue.color.u),
            @(kLyzZMetaxParaboloidButtonValue.color.v),
            @(kLyzZMetaxParaboloidButtonValue.color.w)
        ]];
        __block BOOL reverse = NO;
        NSUInteger mask = 0xFFFFFF;
        [colors enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx > 2) {
                *stop = YES;
                return;
            }
            NSUInteger value = ([obj unsignedIntegerValue]&mask) | ((reverse?0x0:0x1)<<24);
            [cls replaceObjectAtIndex:idx withObject:@(value)];
        }];
        self.colors = [cls copy];
    }
}
- (void)resizeDrawable:(CGFloat)scaleFactor {
    CGSize size = self.bounds.size;
    if (scaleFactor < 1.0f) {
        scaleFactor = 1.0f;
    }
    size.width *= scaleFactor;
    size.height *= scaleFactor;
    @synchronized (_metalLayer) {
        if (fabs(size.width - _metalLayer.drawableSize.width) < 0.1 &&
           fabs(size.height == _metalLayer.drawableSize.height) < 0.1) {
            return;
        }
        _metalLayer.drawableSize = size;
        _viewPort = {
            .originX = -size.width * 9.5,
            .originY = -size.height * 9.5,
            .width = size.width * 20.0f,
            .height = size.height * 20.0f,
            .znear = kLyzZMetaxParaboloidPipelineNearValue,
            .zfar = kLyzZMetaxParaboloidPipelineFarValue
        };
        [self drawableResize:size];
        [self setupDepthTexture:size];
    }
}

- (void)renderOnEvent {
    /// 异步线程渲染
    [self performSelector:@selector(render) onThread:_renderThread withObject:nil waitUntilDone:NO modes:@[kLyzZMetaxParaboloidRunloopMode]];
}

- (void)runThread {
    /// 线程常驻
     NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [_displayLink addToRunLoop:runloop forMode:kLyzZMetaxParaboloidRunloopMode];
    BOOL continueRunloop = YES;
    while (continueRunloop) {
        @autoreleasepool {
            /// 执行来自displaylink的循环
            [runloop runMode:kLyzZMetaxParaboloidRunloopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            /// [NSDate distantFuture]
        }
        @synchronized (self) {
            continueRunloop = _continueRunLoop;
        }
    }
}

- (void)setupDisplayLinkForScreen:(UIScreen *)screen {
    if (!screen || ![screen isKindOfClass:[UIScreen class]]) {
        return;
    }
    [self stopRenderLoop];
    LyzZVzxMetalWeakProxy *proxy = [LyzZVzxMetalWeakProxy proxyWithTarget:self];
    _displayLink = [screen displayLinkWithTarget:proxy selector:@selector(render)];
    _displayLink.paused = self.paused;
    if (@available(iOS 10.0, *)) {
        _displayLink.preferredFramesPerSecond = self.framesPerSecond;
    } else {
        _displayLink.frameInterval = self.framesPerSecond;
    }
}

- (void)setAnimationStartegyPipelineValues {
    const NSUInteger length = 3;
    vector_float3  angulr[length] = {
        self.uPipeline.rotateValue,
        self.vPipeline.rotateValue,
        self.wPipeline.rotateValue
    };
    vector_float3  translates[length] = {
        self.uPipeline.translateValue,
        self.vPipeline.translateValue,
        self.wPipeline.translateValue
    };
    [self.animationStartegy setPipelinesAngular:angulr translate:translates length:length];
}

- (void)updateAnimationStrategy:(LyzZMetaxParaboloidAnimationStrategy *)strategy {
    if (strategy.next) {
        lyzzvs::matrixCopy(strategy.next->startMatrix, strategy->nextmMatrix, 3);
    }
    lyzzvs::matrixCopy(self.animationStartegy->modelMatrix, strategy->prevmMatrix, 3);
    if (self.animationStartegy) {
        [self.animationStartegy resetToInitial];
    }
//    self.uPipeline.translateValue = [strategy translateStartValueFor:self.uPipeline];
//    self.vPipeline.translateValue = [strategy translateStartValueFor:self.vPipeline];
//    self.wPipeline.translateValue = [strategy translateStartValueFor:self.wPipeline];
    self.animationStartegy = strategy;
    [self setAnimationStartegyPipelineValues];
}

#pragma mark - action
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
//    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - private: vertext build
/*
 1、pow(x,2)/pow(a,2) - pow(y,2)/pow(b,2) - z = 0;
 2、y = pow(1-pow(x,m), 1/n);
 */
- (CGFloat)zPosition:(CGFloat)x xD:(CGFloat)xD y:(CGFloat)y yD:(CGFloat)yD{
    return (x * x) / xD - (y * y) / yD;
}

- (vector_float4)vertexColor:(NSUInteger)color index:(NSUInteger)index {
    NSUInteger number = kLyzZVzxBtnVertexListCount;
    uint8_t mask = 0xff;
    BOOL asc_order = ((color>>24)&mask) == 1;
    float alpha = 1.0f;
    if (asc_order) {
        alpha = 1.0f - float(index)/number;
    } else {
        alpha = 0.0f + float(index)/number;
    }
    vector_float4 c = {
        static_cast<float>(((color>>16)&mask)/255.0f),
        static_cast<float>(((color>>8)&mask)/255.0f),
        static_cast<float>((color&mask)/255.0f),
        alpha
    };
    return c;
}

- (void)buildVertices {
    NSUInteger number = kLyzZVzxBtnSampNumber;
    NSUInteger length = kLyzZVzxBtnVertexListCount;
    NSUInteger size = sizeof(LyzZVzxParaboloidVertex) * length * length;
    bzero(_verticesPointer, size);
    CGFloat lhs = - 1.0f, rhs =  1.0f;
    CGFloat stride = (rhs-lhs) / number;
    NSUInteger i = 0;
    for (CGFloat x = lhs; x < rhs + stride && i < length; x += stride, i++) {
        LyzZVzxParaboloidVertex vertex;
        vertex.ucolor = [self vertexColor:[self.colors[0] unsignedIntegerValue] index:i];
        vertex.vcolor = [self vertexColor:[self.colors[1] unsignedIntegerValue] index:i];
        vertex.wcolor = [self vertexColor:[self.colors[2] unsignedIntegerValue] index:i];
        /// y = pow(1-pow(x,m), 1/n);
        CGFloat base = 1.0f - pow(std::abs(x), kLyzZMetaxParaboloidButtonValue.squircle.power);
        CGFloat pw = pow(std::abs(base), 1.0f/kLyzZMetaxParaboloidButtonValue.squircle.rpower);
        CGFloat upper = base < 0 ? -pw : pw;
        //base = pow(std::abs(x), kLyzZMetaxParaboloidButtonValue.squircle.power) - 1.0f;
        //pw = pow(std::abs(base), 1 / (kLyzZMetaxParaboloidButtonValue.squircle.rpower));
        CGFloat lower = - upper;
        //base < 0 ? -pw : pw;
        for (NSUInteger j = 0; j < length; j++) {
            CGFloat y = lower + j * (upper - lower)/number;
            CGFloat z1 = [self zPosition:x xD:5 y:y yD:5];
            CGFloat z2 = [self zPosition:x xD:2 y:y yD:2];
            vertex.position = (vector_float4) {
                static_cast<float>(x),
                static_cast<float>(y),
                static_cast<float>(z1),
                static_cast<float>(z2)
            };
            _verticesPointer[j][i] = vertex;
        }
    }
    [self newVertexBufferWithBytes:_verticesPointer length:size];
}

/**
 o    o   o    o
 |  /|  /|  /|
 | / | / | / |
 o/  o/  o/  o
 ...
 */
- (BOOL)buildPrimitivesIndexBuffer {
    NSUInteger number = kLyzZVzxBtnVertexListCount;
    size_t size = number * number;
    if (_verticesBuffer == nil || _verticesBuffer.length != sizeof(LyzZVzxParaboloidVertex) * size) {
        return NO;
    }
    size_t length = size * 2;
    UInt16 indexes[length];
    bzero(indexes, length * sizeof(UInt16));
    UInt32 index = 0;
    NSInteger i = 1;
    while (1) {
        if (i >= number) {
            break;
        }
        for (NSInteger j = 0; j < number; j++) {
            indexes[index++] = (UInt16)((i - 1) * number + j);
            indexes[index++] = (UInt16)(i * number + j);
        }
        i++;
        if (i >= number) {
            break;
        }
        for (NSInteger j = number - 1; j >= 0; j--) {
            indexes[index++] = (UInt16)((i - 1) * number + j);
            indexes[index++] = (UInt16)(i * number + j);
        }
        i++;
    }
    _primitivesIndexBuffer = [self.device newBufferWithBytes:indexes length:index * sizeof(UInt16) options:MTLResourceStorageModeShared];
    return YES;
}

#pragma mark - render
- (void)render {
    NSTimeInterval frameTime = CFAbsoluteTimeGetCurrent();
    NSTimeInterval frameDuration = frameTime - self.lastFrameTime;
    self.lastFrameTime = frameTime;
    [self renderToMetalPipeline:frameDuration];
}

- (void)drawTrianglesEncoder:(id<MTLRenderCommandEncoder>)commandEncoder {
    /// vertices
    [commandEncoder setVertexBuffer:_verticesBuffer offset:0 atIndex:LyzZVzxParaboloidVertextInputVerticesIndex];
    
    /// uniforms
    CGSize drawableSize = self.metalLayer.drawableSize;
    LyzZVzxParaboloidLayerUniforms layerUniforms;
    LyzZVzxParaboloidUniforms uBuffer;
    if ([self.uPipeline buildUniformsBuffer:&uBuffer drawableSize:drawableSize]) {
        uint16_t flag = uBuffer.flag | ((self.animationStartegy.type & 0xf)<<2);
        uBuffer.flag = flag;
        uBuffer.zProgress = self.animationStartegy.zProgress;
        uBuffer.lhs = self.animationStartegy.lhs;
        uBuffer.rhs = self.animationStartegy.rhs;
    }
    layerUniforms.items[0] = uBuffer;
   
    LyzZVzxParaboloidUniforms vBuffer;
    if ([self.vPipeline buildUniformsBuffer:&vBuffer drawableSize:drawableSize]) {
        uint16_t flag = vBuffer.flag | ((self.animationStartegy.type & 0xf)<<2);
        vBuffer.flag = flag;
        vBuffer.zProgress = self.animationStartegy.zProgress;
        vBuffer.lhs = self.animationStartegy.lhs;
        vBuffer.rhs = self.animationStartegy.rhs;
    }
    layerUniforms.items[1] = vBuffer;
    
    LyzZVzxParaboloidUniforms wBuffer;
    if ([self.wPipeline buildUniformsBuffer:&wBuffer drawableSize:drawableSize]) {
        uint16_t flag = wBuffer.flag | ((self.animationStartegy.type & 0xf)<<2);
        wBuffer.flag = flag;
        wBuffer.zProgress = self.animationStartegy.zProgress;
        wBuffer.lhs = self.animationStartegy.lhs;
        wBuffer.rhs = self.animationStartegy.rhs;
    }
    layerUniforms.items[2] = wBuffer;
    
    id<MTLBuffer> uniform_buffer = [self.device newBufferWithBytes:(void *)&layerUniforms length:sizeof(LyzZVzxParaboloidLayerUniforms) options:MTLResourceStorageModeShared];
    [commandEncoder setVertexBuffer:uniform_buffer offset:0 atIndex:LyzZVzxParaboloidVertextInputUniformsIndex];
    
    /// 设置视口
    [commandEncoder setViewport:[self viewPort]];
    
    NSUInteger indexCount = _primitivesIndexBuffer.length / sizeof(UInt16);
    // [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangleStrip indexCount:indexCount indexType:MTLIndexTypeUInt16 indexBuffer:_primitivesIndexBuffer indexBufferOffset:0];
    /// https://metalbyexample.com/instanced-rendering/  Issuing the Draw Call
    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangleStrip indexCount:indexCount indexType:MTLIndexTypeUInt16 indexBuffer:_primitivesIndexBuffer indexBufferOffset:0 instanceCount:3];
}

- (void)endRenderPerFrame:(id<MTLCommandBuffer>)commandBuffer
                  encoder:(id<MTLRenderCommandEncoder>)commandEncoder
                 drawable:(id<MTLDrawable>)drawable {
    if (commandEncoder) {
        [commandEncoder endEncoding];
    }
    if (drawable) {
        [commandBuffer presentDrawable:drawable];
    }
    [commandBuffer commit];
}

#pragma mark - public
- (void)newVertexBufferWithBytes:(const void *)pointer length:(NSUInteger)length {
    if (pointer == nil || length <= 0) {
        return;
    }
    _verticesBuffer = [self.device newBufferWithBytes:pointer length:length options:MTLResourceStorageModeShared];
}

- (void)renderToMetalLayer {
    /// 异步线程执行
    BOOL isReady = NO;
    if (0 == pthread_rwlock_tryrdlock(&_modelRWLock)) {
        isReady = _modelReady;
        pthread_rwlock_unlock(&_modelRWLock);
    }
    if (!isReady || _metalLayer == nil || self.commandQueue == nil || self.renderDescriptor == nil || self.plState == nil) {
        return;
    }
    id <MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<CAMetalDrawable> currentDrawable = [self.metalLayer nextDrawable];
    if (!currentDrawable) {
        return;
    }
    MTLRenderPassDescriptor *renderPassDescriptor = self.renderDescriptor;
    /// color
    renderPassDescriptor.colorAttachments[0].texture = currentDrawable.texture;
    /// depth
    if (self.depthTexture) {
        renderPassDescriptor.depthAttachment.texture = self.depthTexture;
    }
    
    id <MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderCommandEncoder setRenderPipelineState:self.plState];
    [self drawTrianglesEncoder:renderCommandEncoder];
    [self endRenderPerFrame:commandBuffer encoder:renderCommandEncoder drawable:currentDrawable];
}

#pragma mark - LyzZMetaxParaboloidPipelineDelegate
- (LyzZMetaxParaboloidAnimationStrategy *)currentAnimationStrategy {
    return self.animationStartegy;
}

- (void)pipelineStageDidCompleteShouldChangeStrategy:(LyzZMetaxParaboloidPipeline *)pipeline {
    if (pipeline.currentIndex < 2) {
        return;
    }
    LyzZMetaxParaboloidAnimationStrategy *strategy = self.animationStartegy.next;
    if (!strategy || ![strategy isKindOfClass:[LyzZMetaxParaboloidAnimationStrategy class]]) {
        return;
    }
    [self performSelector:@selector(updateAnimationStrategy:) onThread:_renderThread withObject:strategy waitUntilDone:YES modes:@[kLyzZMetaxParaboloidRunloopMode]];
}

#pragma mark - LyzZMetaxParaboloidViewDelegate
- (void)drawableResize:(CGSize)size {
    /// 异步线程执行
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

- (void)renderToMetalPipeline:(NSTimeInterval)duration {
    [self.uPipeline pipelineModelMatrix:duration];
    [self.vPipeline pipelineModelMatrix:duration];
    [self.wPipeline pipelineModelMatrix:duration];
    [self renderToMetalLayer];
}

#pragma mark - enter Background/Foreground
- (void)didEnterBackground:(NSNotification*)notification {
    self.paused = YES;
}

- (void)willEnterForeground:(NSNotification*)notification {
    self.paused = NO;
}

#pragma mark - public

- (void)setSpinningSpeed:(NSUInteger)index x:(CGFloat)x y:(CGFloat)y z:(CGFloat)z {
    vector_float3 angular = (vector_float3){static_cast<float>(x), static_cast<float>(y), static_cast<float>(z)};
    switch (index) {
        case 1: self.uPipeline.angularVelocity = angular; break;
        case 2: self.vPipeline.angularVelocity = angular; break;
        case 3: self.wPipeline.angularVelocity = angular; break;
        default: {
            self.uPipeline.angularVelocity = angular;
            self.vPipeline.angularVelocity = angular;
            self.wPipeline.angularVelocity = angular;
        }
            break;
    }
}

- (void)setCurvedSurfaceColor:(NSArray <NSNumber *>*)colors {
    [self updateColor:colors];
    if (_verticesPointer == NULL) {
        return;
    }
    NSUInteger length = kLyzZVzxBtnVertexListCount;
    NSUInteger size = sizeof(LyzZVzxParaboloidVertex) * length * length;
    NSUInteger uColor = [self.colors[0] unsignedIntegerValue];
    NSUInteger vColor = [self.colors[1] unsignedIntegerValue];
    NSUInteger wColor = [self.colors[2] unsignedIntegerValue];
    for (int i = 0; i < length; i++) {
        vector_float4 ucolorVec = [self vertexColor:uColor index:i];
        vector_float4 vcolorVec = [self vertexColor:vColor index:i];
        vector_float4 wcolorVec = [self vertexColor:wColor index:i];
        for (int j = 0; j < length; j++) {
            _verticesPointer[j][i].ucolor = ucolorVec;
            _verticesPointer[j][i].vcolor = vcolorVec;
            _verticesPointer[j][i].wcolor = wcolorVec;
        }
    }
    [self newVertexBufferWithBytes:_verticesPointer length:size];
}

- (BOOL)setCurrentStyle:(LyzZMetaxParaboloidButtonStyle)style {
    LyzZMetaxParaboloidAnimationStrategy *targetStrategy;
    switch (style) {
        case LyzZMetaxParaboloidButtonNormalStyle: {
            targetStrategy = self.normalStrategy;
        }
            break;
        case LyzZMetaxParaboloidButtonListenningStyle: {
            targetStrategy = self.listenningStrategy;
        }
            break;
        case LyzZMetaxParaboloidButtonLoadingStyle: {
            targetStrategy = self.loadingStrategy;
        }
            break;
        default:
            break;
    }
    if (targetStrategy == nil || ![targetStrategy isKindOfClass:[LyzZMetaxParaboloidAnimationStrategy class]]) {
        return NO;
    }
    self.transitionStrategy.next = targetStrategy;
    self.transitionStrategy->viewMatrix = targetStrategy->viewMatrix;
    if (_renderThread == nil) {
        self.animationStartegy = targetStrategy;
    } else {
        [self performSelector:@selector(updateAnimationStrategy:) onThread:_renderThread withObject:self.transitionStrategy waitUntilDone:NO modes:@[kLyzZMetaxParaboloidRunloopMode]];
    }
    return YES;
}

- (void)stopRenderLoop {
    @synchronized (self) {
        [_displayLink invalidate];
        _displayLink = nil;
        _continueRunLoop = NO;
    }
}
@end
