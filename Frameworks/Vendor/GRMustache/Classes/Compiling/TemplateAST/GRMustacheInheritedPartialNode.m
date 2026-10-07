// The MIT License
//
// Copyright (c) 2014 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "GRMustacheInheritedPartialNode_private.h"
#import "GRMustachePartialNode_private.h"
#import "GRMustacheTemplateAST_private.h"
#import "GRMustacheTemplateASTVisitor_private.h"

@implementation GRMustacheInheritedPartialNode
@synthesize overridingTemplateAST=_overridingTemplateAST;
@synthesize parentPartialNode=_parentPartialNode;

+ (instancetype)inheritedPartialNodeWithParentPartialNode:(GRMustachePartialNode *)parentPartialNode overridingTemplateAST:(GRMustacheTemplateAST *)overridingTemplateAST
{
    return [[[self alloc] initWithParentPartialNode:parentPartialNode overridingTemplateAST:overridingTemplateAST] autorelease];
}

- (void)dealloc
{
    [_parentPartialNode release];
    [_overridingTemplateAST release];
    [super dealloc];
}


#pragma mark - GRMustacheTemplateASTNode

- (BOOL)acceptTemplateASTVisitor:(id<GRMustacheTemplateASTVisitor>)visitor error:(NSError **)error
{
    return [visitor visitInheritedPartialNode:self error:error];
}

- (id<GRMustacheTemplateASTNode>)resolveTemplateASTNode:(id<GRMustacheTemplateASTNode>)templateASTNode
{
    // {{< partial }}...{{/ partial }}
    //
    // Inherited partials can provide an override in two ways: in
    // the parent partial, and inside the overriding section.
    //
    // Relevant tests:
    //
    // {
    //   "name": "Two levels of inheritance: inherited partial with overriding content containing another inherited partial",
    //   "data": { },
    //   "template": "{{<partial}}{{<partial2}}{{/partial2}}{{/partial}}",
    //   "partials": {
    //       "partial": "{{$inheritable}}ignored{{/inheritable}}",
    //       "partial2": "{{$inheritable}}inherited{{/inheritable}}" },
    //   "expected": "inherited"
    // },
    // {
    //   "name": "Two levels of inheritance: inherited partial with overriding content containing another inherited partial with overriding content containing an inheritable section",
    //   "data": { },
    //   "template": "{{<partial}}{{<partial2}}{{$inheritable}}inherited{{/inheritable}}{{/partial2}}{{/partial}}",
    //   "partials": {
    //       "partial": "{{$inheritable}}ignored{{/inheritable}}",
    //       "partial2": "{{$inheritable}}ignored{{/inheritable}}" },
    //   "expected": "inherited"
    // }
    
    for (id<GRMustacheTemplateASTNode> overridingNode in _parentPartialNode.templateAST.templateASTNodes) {
        templateASTNode = [overridingNode resolveTemplateASTNode:templateASTNode];
    }

    for (id<GRMustacheTemplateASTNode> overridingNode in _overridingTemplateAST.templateASTNodes) {
        templateASTNode = [overridingNode resolveTemplateASTNode:templateASTNode];
    }

    return templateASTNode;
}


#pragma mark - Private

- (instancetype)initWithParentPartialNode:(GRMustachePartialNode *)parentPartialNode overridingTemplateAST:(GRMustacheTemplateAST *)overridingTemplateAST
{
    self = [super init];
    if (self) {
        _parentPartialNode = [parentPartialNode retain];
        _overridingTemplateAST = [overridingTemplateAST retain];
    }
    return self;
}

@end
